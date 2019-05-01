import Foundation
import RxSwift

class PeerGroup {
    private var disposable: Disposable?

    private let factory: IFactory

    private let reachabilityManager: IReachabilityManager
    private var peerAddressManager: IPeerAddressManager
    private var peerManager: IPeerManager

    private var peerCount: Int

    private var started: Bool = false
    private var _started: Bool = false


    private let peersQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue

    var blockSyncer: IBlockSyncer?
    var transactionSyncer: ITransactionSyncer?

    private let logger: Logger?

    var inventoryItemsHandler: IInventoryItemsHandler? = nil
    var peerTaskHandler: IPeerTaskHandler? = nil

    private var peerGroupListeners = [IPeerGroupListener]()

    init(factory: IFactory, reachabilityManager: IReachabilityManager,
         peerAddressManager: IPeerAddressManager, peerCount: Int = 10, peerManager: IPeerManager,
         peersQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated),
         inventoryQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background),
         logger: Logger? = nil) {
        self.factory = factory

        self.reachabilityManager = reachabilityManager
        self.peerAddressManager = peerAddressManager
        self.peerCount = peerCount
        self.peerManager = peerManager

        self.peersQueue = peersQueue
        self.inventoryQueue = inventoryQueue

        self.logger = logger

        self.peerAddressManager.delegate = self
    }

    deinit {
        disposable?.dispose()
    }

    func add(listener: IPeerGroupListener) {
        peerGroupListeners.append(listener)
    }

    private func connectPeersIfRequired() {
        peersQueue.async {
            guard self.started, self.reachabilityManager.isReachable else {
                return
            }

            for _ in self.peerManager.totalPeersCount()..<self.peerCount {
                if let host = self.peerAddressManager.ip {
                    let peer = self.factory.peer(withHost: host, logger: self.logger)
                    peer.delegate = self
                    self.peerGroupListeners.forEach { $0.onPeerCreate(peer: peer) }

                    self.peerManager.add(peer: peer)
                    peer.connect()
                } else {
                    break
                }
            }
        }
    }

    private func _start() {
        guard started, _started == false else {
            return
        }

        _started = true

        peerGroupListeners.forEach { $0.onStart() } // potential broke order of call functions
        connectPeersIfRequired()
    }

    private func _stop() {
        _started = false

        peerManager.disconnectAll()
        peerGroupListeners.forEach { $0.onStop() }
    }

}

extension PeerGroup: IPeerGroup {

    func add(peerGroupListener: IPeerGroupListener) {
        peerGroupListeners.append(peerGroupListener)
    }

    var someReadyPeers: [IPeer] {
        return peerManager.someReadyPeers()
    }

    func start() {
        guard started == false else {
            return
        }

        started = true

        // Subscribe to ReachabilityManager
        disposable = reachabilityManager.reachabilitySignal.subscribe(onNext: { [weak self] in
            self?.onChangeConnection()
        })

        if reachabilityManager.isReachable {
            _start()
        }
    }

    private func onChangeConnection() {
        if reachabilityManager.isReachable {
            _start()
        } else {
            _stop()
        }
    }

    func stop() {
        started = false

        // Unsubscribe to ReachabilityManager
        disposable?.dispose()

        _stop()
    }

    func checkPeersSynced() throws {
        guard peerManager.connected().count > 0 else {
            throw BitcoinCoreErrors.PeerGroup.noConnectedPeers
        }

        guard peerManager.halfIsSynced() else {
            throw BitcoinCoreErrors.PeerGroup.peersNotSynced
        }
    }

}

extension PeerGroup: PeerDelegate {

    func peerReady(_ peer: IPeer) {
        self.peerGroupListeners.forEach { $0.onPeerReady(peer: peer) }
    }

    func peerDidConnect(_ peer: IPeer) {
        peerGroupListeners.forEach { $0.onPeerConnect(peer: peer) }
    }

    func peerDidDisconnect(_ peer: IPeer, withError error: Error?) {
        peersQueue.async {
            self.peerManager.peerDisconnected(peer: peer)
        }

        if let error = error {
            logger?.warning("Peer \(peer.logName)(\(peer.host)) disconnected. Network reachable: \(reachabilityManager.isReachable). Error: \(error)")
        }

        if reachabilityManager.isReachable && error != nil {
            peerAddressManager.markFailed(ip: peer.host)
        } else {
            peerAddressManager.markSuccess(ip: peer.host)
        }

        self.peerGroupListeners.forEach { $0.onPeerDisconnect(peer: peer, error: error) }
        connectPeersIfRequired()
    }

    func peer(_ peer: IPeer, didCompleteTask task: PeerTask) {
        _ = peerTaskHandler?.handleCompletedTask(peer: peer, task: task)
    }

    func peer(_ peer: IPeer, didReceiveAddresses addresses: [NetworkAddress]) {
        self.peerAddressManager.add(ips: addresses.map {
            $0.address
        })
    }

    func peer(_ peer: IPeer, didReceiveInventoryItems items: [InventoryItem]) {
        inventoryQueue.async {
            self.inventoryItemsHandler?.handleInventoryItems(peer: peer, inventoryItems: items)
        }
    }

}

extension PeerGroup: IPeerAddressManagerDelegate {

    func newIpsAdded() {
        connectPeersIfRequired()
    }

}
