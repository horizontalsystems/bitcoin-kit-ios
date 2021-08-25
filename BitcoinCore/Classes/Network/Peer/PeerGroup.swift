import Foundation
import RxSwift
import HsToolKit
import NIO

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
    private static let acceptableBlockHeightDifference = 50_000
    private static let peerCountToConnect = 100

    private let factory: IFactory

    private let reachabilityManager: IReachabilityManager
    private var peerAddressManager: IPeerAddressManager
    private var peerManager: IPeerManager

    private let localDownloadedBestBlockHeight: Int32
    private let peerCountToHold: Int            // number of peers held
    private var peerCountToConnect: Int?        // number of peers to connect to
    private var peerCountConnected = 0          // number of peers connected to

    private var started: Bool = false

    private let peersQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue
    private let subjectQueue: DispatchQueue
    private var eventLoopGroup: MultiThreadedEventLoopGroup

    private let logger: Logger?

    weak var inventoryItemsHandler: IInventoryItemsHandler? = nil
    weak var peerTaskHandler: IPeerTaskHandler? = nil

    private let subject = PublishSubject<PeerGroupEvent>()
    let observable: Observable<PeerGroupEvent>

    init(factory: IFactory, reachabilityManager: IReachabilityManager,
         peerAddressManager: IPeerAddressManager, peerCount: Int = 10, localDownloadedBestBlockHeight: Int32,
         peerManager: IPeerManager, peersQueue: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.peer-group.peers", qos: .userInitiated),
         inventoryQueue: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.peer-group.inventory", qos: .background),
         subjectQueue: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.peer-group.subject", qos: .background),
         scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .background),
         logger: Logger? = nil) {
        self.factory = factory

        self.reachabilityManager = reachabilityManager
        self.peerAddressManager = peerAddressManager
        self.localDownloadedBestBlockHeight = localDownloadedBestBlockHeight
        self.peerCountToHold = peerCount
        self.peerManager = peerManager

        self.peersQueue = peersQueue
        self.inventoryQueue = inventoryQueue
        self.subjectQueue = subjectQueue
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: peerCount)

        self.logger = logger
        self.observable = subject.asObservable().observeOn(scheduler)

        self.peerAddressManager.delegate = self
    }

    deinit {
        eventLoopGroup.shutdownGracefully { _ in }
    }

    private func connectPeersIfRequired() {
        peersQueue.async {
            guard self.started, self.reachabilityManager.isReachable else {
                return
            }

            var peersToConnect = [IPeer]()

            for _ in self.peerManager.totalPeersCount..<self.peerCountToHold {
                if let host = self.peerAddressManager.ip {
                    let peer = self.factory.peer(withHost: host, eventLoopGroup: self.eventLoopGroup, logger: self.logger)
                    peer.delegate = self
                    peersToConnect.append(peer)
                } else {
                    break
                }
            }

            for peer in peersToConnect {
                self.peerCountConnected += 1
                self.onNext(.onPeerCreate(peer: peer))
                self.peerManager.add(peer: peer)
                peer.connect()
            }
        }
    }

    private func onNext(_ event: PeerGroupEvent) {
        subjectQueue.async {
            self.subject.onNext(event)
        }
    }

}

extension PeerGroup: IPeerGroup {

    func start() {
        guard started == false else {
            return
        }

        started = true
        peerCountConnected = 0

        onNext(.onStart)
        connectPeersIfRequired()
    }

    func stop() {
        started = false

        peerManager.disconnectAll()
        onNext(.onStop)
    }

    func reconnectPeers() {
        peerManager.disconnectAll()
    }

    func isReady(peer: IPeer) -> Bool {
        peer.ready
    }

}

extension PeerGroup: PeerDelegate {

    func peerReady(_ peer: IPeer) {
        onNext(.onPeerReady(peer: peer))
    }

    func peerBusy(_ peer: IPeer) {
        onNext(.onPeerBusy(peer: peer))
    }

    func peerDidConnect(_ peer: IPeer) {
        peerAddressManager.markConnected(peer: peer)
        onNext(.onPeerConnect(peer: peer))

        if let peerCountToConnect = peerCountToConnect {
            disconnectSlowestPeer(peerCountToConnect: peerCountToConnect)
        } else {
            setPeerCountToConnect(for: peer)
        }
    }

    private func setPeerCountToConnect(for peer: IPeer) {
        if peer.announcedLastBlockHeight - localDownloadedBestBlockHeight > PeerGroup.acceptableBlockHeightDifference {
            peerCountToConnect = PeerGroup.peerCountToConnect
        } else {
            peerCountToConnect = 0
        }
    }

    private func disconnectSlowestPeer(peerCountToConnect: Int) {
        if peerCountToConnect > peerCountConnected && peerCountToHold > 1 && peerAddressManager.hasFreshIps {
            let sortedPeers = peerManager.sorted
            if sortedPeers.count >= peerCountToHold {
                sortedPeers.last?.disconnect(error: nil)
            }
        }
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

        onNext(.onPeerDisconnect(peer: peer, error: error))
        connectPeersIfRequired()
    }

    func peer(_ peer: IPeer, didCompleteTask task: PeerTask) {
        _ = peerTaskHandler?.handleCompletedTask(peer: peer, task: task)
    }

    func peer(_ peer: IPeer, didReceiveMessage message: IMessage) {
        switch message {
        case let addressMessage as AddressMessage:
            let addresses = addressMessage.addressList
                    .filter { $0.supportsBloomFilter() }
                    .map { $0.address }

            peerAddressManager.add(ips: addresses)
        case let inventoryMessage as InventoryMessage:
            inventoryQueue.async {
                self.inventoryItemsHandler?.handleInventoryItems(peer: peer, inventoryItems: inventoryMessage.inventoryItems)
            }
        default: ()
        }
    }

}

extension PeerGroup: IPeerAddressManagerDelegate {

    func newIpsAdded() {
        connectPeersIfRequired()
    }

}
