import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    enum Status {
        case connected, disconnected
    }

    private let blocksPerPeer: Int = 10
    var statusSubject: PublishSubject<Status> = PublishSubject()
    weak var delegate: PeerGroupDelegate?

    private let network: NetworkProtocol
    var bloomFilters: [Data]
    private let peerIpManager: PeerIpManager
    private var peerCount: Int

    private var syncPeer: Peer?
    private var fetchingBlockHashesQueue: [Data] = []
    private let inventoryQueue: DispatchQueue
    private var requestedInventories: [Data: InventoryItem] = [:]
    private var requestingBlocks: Bool = false
    private var peers: [String: Peer] = [:]

    var readyNonSyncPeers: [Peer] {
        let peers = self.peers.values.filter({ peer in peer.status == .ready })
        guard let syncPeer = self.syncPeer else {
            return peers
        }

        return peers.filter({ peer in peer != syncPeer })
    }

    init(network: NetworkProtocol, bloomFilters: [Data], peerIpManager: PeerIpManager, peerCount: Int = 3) {
        self.network = network
        self.bloomFilters = bloomFilters
        self.peerIpManager = peerIpManager
        self.peerCount = peerCount
        inventoryQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background)
    }

    func connect() {
        connectPeersIfRequired()
    }

    func connectPeersIfRequired() {
        for _ in peers.count..<peerCount {
            if let host = peerIpManager.peerHost {
                let peer = Peer(host: host, network: network)
                peers[host] = peer
                peer.delegate = self
                peer.connect()
            } else {
                Logger.shared.log(self, "No peers found!")
                break
            }
        }
    }

    func requestHeaders(headerHashes: [Data], switchPeer: Bool = false) {
        if switchPeer {
            switchSyncPeer()
        }

        syncPeer?.sendGetHeadersMessage(headerHashes: headerHashes)
    }

    func requestMerkleBlocks(headerHashes: [Data]) {
        for hash in headerHashes {
            fetchingBlockHashesQueue.append(hash)
        }

        for peer in readyNonSyncPeers {
            requestMerkleBlocksPart(peer: peer)
        }
    }

    func relay(transaction: Transaction) {
        for peerElement in peers {
            peerElement.value.relay(transaction: transaction)
        }
    }

    func addPublicKeyFilter(pubKey: PublicKey) {
        if !bloomFilters.contains(pubKey.raw!) {
            bloomFilters.append(pubKey.keyHash)
            bloomFilters.append(pubKey.raw!)
        }

        for peerElement in peers {
            peerElement.value.addFilter(filter: pubKey.keyHash)
            peerElement.value.addFilter(filter: pubKey.raw!)
        }
    }

    private func requestMerkleBlocksPart(peer: Peer) {
        guard !requestingBlocks else {
            return
        }
        requestingBlocks = true

        let hashes = fetchingBlockHashesQueue.prefix(blocksPerPeer)
        if !hashes.isEmpty {
            fetchingBlockHashesQueue.removeFirst(hashes.count)
            peer.requestMerkleBlocks(headerHashes: Array(hashes))
        }

        requestingBlocks = false
    }

    private func switchSyncPeer() {
        if let readyPeer = readyPeer() {
            syncPeer = readyPeer
        }
    }

    private func readyPeer() -> Peer? {
        return readyNonSyncPeers.first
    }

}

extension PeerGroup: PeerDelegate {
    func peerReady(_ peer: Peer) {
        statusSubject.onNext(.connected)

        if syncPeer == nil {
            Logger.shared.log(self, "syncPeer set to \(peer.host)")
            syncPeer = peer
        }

        if peers.values.filter({ peer in peer.status.connected }).count == 1 {
            delegate?.peerGroupReady()
        }

        requestMerkleBlocksPart(peer: peer)
    }

    func peerDidDisconnect(_ peer: Peer) {
        if let syncPeer = self.syncPeer, syncPeer == peer {
            // it restores syncPeer on next peer connection
            self.syncPeer = nil
        }

        _ = peers.removeValue(forKey: peer.host)

        for hash in peer.incompleteMerkleBlockHashes {
            fetchingBlockHashesQueue.append(hash)
        }

        connectPeersIfRequired()

        if peers.values.filter({ peer in peer.status.connected }).isEmpty {
            // delegate?.peerGroupDidDisconnect
        }
    }

    func peer(_ peer: Peer, didReceiveHeaders headers: [BlockHeader]) {
        delegate?.peerGroupDidReceive(headers: headers)
    }

    func peer(_ peer: Peer, didReceiveMerkleBlock merkleBlock: MerkleBlock) {
        requestedInventories.removeValue(forKey: merkleBlock.headerHash)
        delegate?.peerGroupDidReceive(blockHeader: merkleBlock.header, withTransactions: merkleBlock.transactions)
    }

    func peer(_ peer: Peer, didReceiveTransaction transaction: Transaction) {
        requestedInventories.removeValue(forKey: transaction.dataHash)
        delegate?.peerGroupDidReceive(transaction: transaction)
    }

    func runIfShouldRequest(inventoryItem: InventoryItem, _ block: () -> Swift.Void) {
        inventoryQueue.sync {
            if requestedInventories[inventoryItem.hash] != nil {
                return
            }

            let shouldRequest = delegate?.shouldRequest(inventoryItem: inventoryItem) ?? false
            if shouldRequest {
                requestedInventories[inventoryItem.hash] = inventoryItem
                block()
            }
        }
    }

}
