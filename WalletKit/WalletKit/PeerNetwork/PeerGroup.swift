import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    private let blocksPerPeer: Int = 100

    weak var delegate: PeerGroupDelegate?

    private let network: NetworkProtocol
    private let peerIpManager: PeerIpManager
    private var bloomFilters: [Data]
    private var peerCount: Int

    private var started: Bool = false

    private var peers: [Peer] = []
    private var syncPeer: Peer?

    private var allBlocksSynced: Bool = false
    private var allTransactionsRelayed: Bool = false

    private let localQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue
    private let queue: DispatchQueue

    init(network: NetworkProtocol, peerIpManager: PeerIpManager, bloomFilters: [Data], peerCount: Int = 3) {
        self.network = network
        self.peerIpManager = peerIpManager
        self.bloomFilters = bloomFilters
        self.peerCount = peerCount

        localQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated)
        inventoryQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background)
        queue = DispatchQueue(label: "PeerGroup Concurrent Queue", qos: .userInitiated, attributes: .concurrent)

        self.peerIpManager.delegate = self
    }

    func start() {
        started = true
        connectPeersIfRequired()
    }

    func stop() {
        started = false

        for peer in peers {
            peer.disconnect()
        }
    }

    func syncBlocks() {
        if allBlocksSynced {
            allBlocksSynced = false
            checkReadyPeers()
        }
    }

    func sendTransactions() {
        if allTransactionsRelayed {
            allTransactionsRelayed = false
            checkReadyPeers()
        }
    }

    func addPublicKeyFilter(pubKey: PublicKey) {
        if !bloomFilters.contains(pubKey.raw!) {
            bloomFilters.append(pubKey.keyHash)
            bloomFilters.append(pubKey.raw!)
        }

        for peer in peers {
            peer.addFilter(filter: pubKey.keyHash)
            peer.addFilter(filter: pubKey.raw!)
        }
    }

    private func connectPeersIfRequired() {
        guard started else {
            return
        }

        for _ in peers.count..<peerCount {
            if let host = peerIpManager.peerHost {
                let peer = Peer(host: host, network: network)
                peers.append(peer)
                peer.delegate = self
                peer.connect()
            } else {
                Logger.shared.log(self, "No peers found!")
                break
            }
        }
    }

    private func handleReady(peer: Peer) {
        guard peer !== syncPeer && peer.ready else {
            return
        }

        if syncPeer == nil && !peer.headersSynced {
            Logger.shared.log(self, "SETTING SYNC PEER TO \(peer.logName)")
            syncPeer = peer
            handleReadySyncPeer()
        } else {
            if !allTransactionsRelayed {
                relayTransactions(peer: peer)
            }

            if !allBlocksSynced {
                syncBlocks(peer: peer)
            }
        }
    }

    private func handleReadySyncPeer() {
        if let hashes = delegate?.getHeadersHashes() {
            syncPeer?.add(task: RequestHeadersPeerTask(hashes: hashes))
        }
    }

    private func relayTransactions(peer: Peer) {
        if let transactions = delegate?.getNonSentTransactions(), !transactions.isEmpty {
            for transaction in transactions {
                peer.add(task: RelayTransactionPeerTask(transaction: transaction))
            }
        }
        allTransactionsRelayed = true
    }

    private func syncBlocks(peer: Peer) {
        if let hashes = delegate?.getNonSyncedMerkleBlocksHashes(limit: blocksPerPeer) {
            if hashes.isEmpty {
                allBlocksSynced = true
            } else {
                peer.add(task: RequestMerkleBlocksPeerTask(hashes: hashes))
            }
        }
    }

    private func checkReadyPeers() {
        for peer in peers.filter({ $0 !== syncPeer && $0.ready }) {
            localQueue.async {
                self.handleReady(peer: peer)
            }
        }
    }

    private func isRequestingInventory(hash: Data) -> Bool {
        for peer in peers {
            if peer.isRequestingInventory(hash: hash) {
                return true
            }
        }
        return false
    }

    private func handleRelayedTransaction(hash: Data) -> Bool {
        for peer in peers {
            if peer.handleRelayedTransaction(hash: hash) {
                return true
            }
        }
        return false
    }

}

extension PeerGroup: PeerDelegate {

    func getBloomFilters() -> [Data] {
        return bloomFilters
    }

    func peerReady(_ peer: Peer) {
        localQueue.async {
            self.handleReady(peer: peer)
        }
    }

    func peerDidDisconnect(_ peer: Peer, withError error: Bool) {
        if error {
            Logger.shared.log(self, "Peer with IP \(peer.host) disconnected with error")
        }

        peerIpManager.hostDisconnected(host: peer.host, withError: error)

        if peer === syncPeer {
            syncPeer = nil
        }

        if let index = peers.index(where: { $0 === peer }) {
            peers.remove(at: index)
        }

        connectPeersIfRequired()
    }

    func peer(_ peer: Peer, didReceiveHeaders headers: [BlockHeader]) {
        queue.async {
            self.delegate?.peerGroupDidReceive(headers: headers)

            if headers.count < 2000 {
                Logger.shared.log(self, "UNSETTING SYNC PEER")

                self.syncPeer?.headersSynced = true
                self.syncPeer = nil
                self.checkReadyPeers()
            } else {
                self.handleReadySyncPeer()
            }
        }
    }

    func peer(_ peer: Peer, didReceiveMerkleBlock merkleBlock: MerkleBlock) {
        queue.async {
            self.delegate?.peerGroupDidReceive(blockHeader: merkleBlock.header, withTransactions: merkleBlock.transactions)
        }
    }

    func peer(_ peer: Peer, didReceiveTransaction transaction: Transaction) {
        queue.async {
            self.delegate?.peerGroupDidReceive(transaction: transaction)
        }
    }

    func peer(_ peer: Peer, didReceiveAddresses addresses: [NetworkAddress]) {
        queue.async {
            self.peerIpManager.addPeers(hosts: addresses.map { $0.address })
        }
    }

    func peer(_ peer: Peer, didReceiveInventoryItems items: [InventoryItem]) {
        inventoryQueue.async {
            var blockHashes = [Data]()
            var transactionHashes = [Data]()

            for item in items {
                if !self.isRequestingInventory(hash: item.hash) {
                    switch item.objectType {
                    case .blockMessage:
                        if let delegate = self.delegate, delegate.shouldRequestBlock(hash: item.hash) {
                            blockHashes.append(item.hash)
                        }
                    case .transaction:
                        if self.handleRelayedTransaction(hash: item.hash) {
                            continue
                        }

                        if let delegate = self.delegate, delegate.shouldRequestTransaction(hash: item.hash) {
                            transactionHashes.append(item.hash)
                        }
                    default: ()
                    }
                }
            }

            if !blockHashes.isEmpty {
                peer.add(task: RequestMerkleBlocksPeerTask(hashes: blockHashes))
            }
            if !transactionHashes.isEmpty {
                peer.add(task: RequestTransactionsPeerTask(hashes: transactionHashes))
            }
        }
    }

}

extension PeerGroup: PeerIpManagerDelegate {

    func newHostsAdded() {
        connectPeersIfRequired()
    }

}
