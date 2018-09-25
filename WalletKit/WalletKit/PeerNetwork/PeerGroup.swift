import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    private let blocksPerPeer: Int = 100

    weak var delegate: PeerGroupDelegate?

    private let network: NetworkProtocol
    private let peerHostManager: PeerHostManager
    private var bloomFilters: [Data]
    private var peerCount: Int

    private var started: Bool = false

    private var peers: [Peer] = []
    private var syncPeer: Peer?

    private var pendingBlockHashes: [Data] = []
    private var pendingTransactions: [Transaction] = []

    private let localQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue
    private let queue: DispatchQueue

    init(network: NetworkProtocol, peerHostManager: PeerHostManager, bloomFilters: [Data], peerCount: Int = 3) {
        self.network = network
        self.peerHostManager = peerHostManager
        self.bloomFilters = bloomFilters
        self.peerCount = peerCount

        localQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated)
        inventoryQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background)
        queue = DispatchQueue(label: "PeerGroup Concurrent Queue", qos: .userInitiated, attributes: .concurrent)

        self.peerHostManager.delegate = self
    }

    func start() {
        guard started == false else {
            return
        }

        started = true

        addNonSyncedtMerkleBlocks()
        addNonSentTransactions()

        connectPeersIfRequired()
    }

    func stop() {
        started = false

        for peer in peers {
            peer.disconnect()
        }
    }

    func syncBlocks(hashes: [Data]) {
        localQueue.async {
            self.pendingBlockHashes.append(contentsOf: hashes)
            self.dispatchTasks()
        }
    }

    func send(transaction: Transaction) {
        // Transaction is managed by Realm. We need to serialize and deserialize it in order to make it non-managed.
        let data = TransactionSerializer.serialize(transaction: transaction)
        let transaction = TransactionSerializer.deserialize(data: data)

        localQueue.async {
            self.pendingTransactions.append(transaction)
            self.dispatchTasks()
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
            if let host = peerHostManager.peerHost {
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
            for transaction in pendingTransactions {
                peer.add(task: RelayTransactionPeerTask(transaction: transaction))
            }
            pendingTransactions = []

            let hashes = Array(pendingBlockHashes.prefix(blocksPerPeer))

            if !hashes.isEmpty {
                pendingBlockHashes.removeFirst(hashes.count)
                peer.add(task: RequestMerkleBlocksPeerTask(hashes: hashes))
            }
        }
    }

    private func handleReadySyncPeer() {
        if let hashes = self.delegate?.getHeadersHashes() {
            self.syncPeer?.add(task: RequestHeadersPeerTask(hashes: hashes))
        }
    }

    private func dispatchTasks(forReadyPeer peer: Peer? = nil) {
        if let peer = peer {
            handleReady(peer: peer)
        } else {
            for peer in peers.filter({ $0 !== syncPeer && $0.ready }) {
                handleReady(peer: peer)
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

    private func handle(blockHeaders: [BlockHeader]) {
        queue.async {
            self.delegate?.peerGroupDidReceive(headers: blockHeaders)

            if blockHeaders.count < 2000 {
                Logger.shared.log(self, "UNSETTING SYNC PEER FROM \(self.syncPeer?.logName ?? "")")

                self.localQueue.async {
                    self.syncPeer?.headersSynced = true
                    self.syncPeer = nil
                    self.dispatchTasks()
                }
            } else {
                self.handleReadySyncPeer()
            }
        }
    }

    private func handle(merkleBlocks: [MerkleBlock]) {
        queue.async {
            self.delegate?.peerGroupDidReceive(merkleBlocks: merkleBlocks)
        }
    }

    private func handle(transaction: Transaction) {
        queue.async {
            self.delegate?.peerGroupDidReceive(transaction: transaction)
        }
    }

    private func handle(relayedTransaction transaction: Transaction) {
        // todo: temp solution for setting tx status. It should be handled in more efficient way
        queue.async {
            self.delegate?.peerGroupDidReceive(transaction: transaction)
        }
    }

    private func addNonSyncedtMerkleBlocks() {
        if let hashes = delegate?.getNonSyncedMerkleBlocksHashes() {
            pendingBlockHashes.append(contentsOf: hashes)
        }
    }

    private func addNonSentTransactions() {
        if let transactions = delegate?.getNonSentTransactions() {
            for transaction in transactions {
                send(transaction: transaction)
            }
        }
    }

}

extension PeerGroup: PeerDelegate {

    func getBloomFilters() -> [Data] {
        return bloomFilters
    }

    func peerReady(_ peer: Peer) {
        localQueue.async {
            self.dispatchTasks(forReadyPeer: peer)
        }
    }

    func peerDidDisconnect(_ peer: Peer, withError error: Bool) {
        if error {
            Logger.shared.log(self, "Peer with IP \(peer.host) disconnected with error")
        }

        peerHostManager.hostDisconnected(host: peer.host, withError: error)

        if peer === syncPeer {
            syncPeer = nil
        }

        if let index = peers.index(where: { $0 === peer }) {
            peers.remove(at: index)
        }

        connectPeersIfRequired()
    }

    func peer(_ peer: Peer, didHandleTask task: PeerTask) {
        guard task.completed else {
            // todo: handle failed task
            return
        }

        switch task {

        case let task as RequestHeadersPeerTask:
            handle(blockHeaders: task.blockHeaders)

        case let task as RequestMerkleBlocksPeerTask:
            handle(merkleBlocks: task.merkleBlocks)

        case let task as RequestTransactionsPeerTask:
            for transaction in task.transactions {
                handle(transaction: transaction)
            }

        case let task as RelayTransactionPeerTask:
            handle(relayedTransaction: task.transaction)

        default: ()

        }
    }

    func peer(_ peer: Peer, didReceiveAddresses addresses: [NetworkAddress]) {
        queue.async {
            self.peerHostManager.addHosts(hosts: addresses.map { $0.address })
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

extension PeerGroup: PeerHostManagerDelegate {

    func newHostsAdded() {
        connectPeersIfRequired()
    }

}
