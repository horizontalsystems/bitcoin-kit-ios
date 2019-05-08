import Foundation
import RxSwift

public enum PeerGroupEvent {
    case onStart
    case onStop
    case onPeerCreate(peer: IPeer)
    case onPeerConnect(peer: IPeer)
    case onPeerDisconnect(peer: IPeer, error: Error?)
    case onPeerReady(peer: IPeer)
    case onPeerBusy(peer: IPeer)
}

class PeerGroup {
    private let factory: IFactory

    private let reachabilityManager: IReachabilityManager
    private var peerAddressManager: IPeerAddressManager
    private var peerManager: IPeerManager

    private var peerCount: Int

    private var started: Bool = false
    private var _started: Bool = false


    private let peersQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue

    private let logger: Logger?

    weak var inventoryItemsHandler: IInventoryItemsHandler? = nil
    weak var peerTaskHandler: IPeerTaskHandler? = nil

    private let subject = PublishSubject<PeerGroupEvent>()
    let observable: Observable<PeerGroupEvent>

    init(factory: IFactory, reachabilityManager: IReachabilityManager,
         peerAddressManager: IPeerAddressManager, peerCount: Int = 10, peerManager: IPeerManager,
         peersQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated),
         inventoryQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background),
         scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .background),
         logger: Logger? = nil) {
        self.factory = factory

        self.reachabilityManager = reachabilityManager
        self.peerAddressManager = peerAddressManager
        self.peerCount = peerCount
        self.peerManager = peerManager

        self.peersQueue = peersQueue
        self.inventoryQueue = inventoryQueue

        self.logger = logger
        self.observable = subject.asObservable().observeOn(scheduler)

        self.peerAddressManager.delegate = self
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
                    self.subject.onNext(.onPeerCreate(peer: peer))

                    self.peerManager.add(peer: peer)
                    peer.connect()
                } else {
                    break
                }
            }
        }
    }

}

extension PeerGroup: IPeerGroup {

    func start() {
        guard started == false, reachabilityManager.isReachable else {
            return
        }

        started = true

        self.subject.onNext(.onStart)
        connectPeersIfRequired()
    }

    func stop() {
        started = false

        peerManager.disconnectAll()
        self.subject.onNext(.onStop)
    }

    func isReady(peer: IPeer) -> Bool {
        return peer.ready
    }

}

extension PeerGroup: PeerDelegate {

    func peerReady(_ peer: IPeer) {
        self.subject.onNext(.onPeerReady(peer: peer))
    }

    func peerBusy(_ peer: IPeer) {
        self.subject.onNext(.onPeerBusy(peer: peer))
    }

    func peerDidConnect(_ peer: IPeer) {
        self.subject.onNext(.onPeerConnect(peer: peer))
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

        self.subject.onNext(.onPeerDisconnect(peer: peer, error: error))
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
