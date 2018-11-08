import Foundation
import HSCryptoKit

class Peer {
    enum PeerError: Error {
        case peerBestBlockIsLessThanOne
        case peerHasExpiredBlockChain(localHeight: Int32, peerHeight: Int32)
        case peerNotFullNode
        case peerDoesNotSupportBloomFilter
    }

    private let protocolVersion: Int32 = 70015
    private var sentVersion: Bool = false
    private var sentVerack: Bool = false

    weak var delegate: PeerDelegate?

    private let connection: PeerConnection
    private var tasks: [PeerTask] = []

    private let queue: DispatchQueue
    private let network: INetwork

    var announcedLastBlockHeight: Int32 = 0
    var localBestBlockHeight: Int32 = 0
    var connected: Bool = false
    var blockHashesSynced: Bool = false
    var synced: Bool = false
    var mempoolSent: Bool = false

    var ready: Bool {
        return connected && tasks.isEmpty
    }

    var host: String {
        return connection.host
    }

    var logName: String {
        return connection.logName
    }

    init(host: String, network: INetwork) {
        connection = PeerConnection(host: host, network: network)
        queue = DispatchQueue(label: "Peer: \(host)", qos: .userInitiated)
        self.network = network

        connection.delegate = self
    }

    private func sendVersion() {
        let versionMessage = VersionMessage(
                version: protocolVersion,
                services: 0x00,
                timestamp: Int64(Date().timeIntervalSince1970),
                yourAddress: NetworkAddress(services: 0x00, address: connection.host, port: UInt16(connection.port)),
                myAddress: NetworkAddress(services: 0x00, address: "::ffff:127.0.0.1", port: UInt16(connection.port)),
                nonce: 0,
                userAgent: "/WalletKit:0.1.0/",
                startHeight: localBestBlockHeight,
                relay: false
        )

        log("--> VERSION: \(versionMessage.version) --- \(versionMessage.userAgent?.value ?? "") --- \(ServiceFlags(rawValue: versionMessage.services))")
        connection.send(message: versionMessage)
    }

    private func sendVerack() {
        log("--> VERACK")
        connection.send(message: VerackMessage())
    }

    private func handle(message: IMessage) {
        if let versionMessage = message as? VersionMessage {
            handle(message: versionMessage)
        } else if let _ = message as? VerackMessage {
            handleVerackMessage()
        }

        guard self.connected else {
            return
        }

        switch message {
        case let addressMessage as AddressMessage: handle(message: addressMessage)
        case let inventoryMessage as InventoryMessage: handle(message: inventoryMessage)
        case let getDataMessage as GetDataMessage: handle(message: getDataMessage)
        case let blockMessage as BlockMessage: handle(message: blockMessage)
        case let merkleBlockMessage as MerkleBlockMessage: handle(message: merkleBlockMessage)
        case let transactionMessage as TransactionMessage: handle(message: transactionMessage)
        case let pingMessage as PingMessage: handle(message: pingMessage)
        case let pongMessage as PongMessage: handle(message: pongMessage)
        case let rejectMessage as RejectMessage: handle(message: rejectMessage)
        default: break
        }
    }

    private func handle(message: VersionMessage) {
        log("<-- VERSION: \(message.version) --- \(message.userAgent?.value ?? "") --- \(ServiceFlags(rawValue: message.services)) -- \(String(describing: message.startHeight ?? 0))")
        do {
            try validatePeerVersion(message: message)
        } catch {
            disconnect(error: error)
        }

        self.announcedLastBlockHeight = message.startHeight ?? 0

        if !sentVerack {
            sendVerack()
            sentVerack = true
        }
    }

    private func validatePeerVersion(message: VersionMessage) throws {
        guard let startHeight = message.startHeight, startHeight > 0 else {
            throw PeerError.peerBestBlockIsLessThanOne
        }

        guard startHeight >= localBestBlockHeight else {
            throw PeerError.peerHasExpiredBlockChain(localHeight: localBestBlockHeight, peerHeight: startHeight)
        }

        guard message.hasBlockChain(network: network) else {
            throw PeerError.peerNotFullNode
        }

        guard message.supportsBloomFilter(network: network) else {
            throw PeerError.peerDoesNotSupportBloomFilter
        }
    }

    private func handleVerackMessage() {
        log("<-- VERACK")
        connected = true

        delegate?.peerDidConnect(self)
    }

    private func handle(message: AddressMessage) {
        log("<-- ADDR: \(message.count) address(es)")
        delegate?.peer(self, didReceiveAddresses: message.addressList)
    }

    private func handle(message: InventoryMessage) {
        log("<-- INV: \(message.inventoryItems.map { "[\($0.objectType): \($0.hash.reversedHex)]" }.joined(separator: ", "))")

        for task in tasks {
            if task.handle(items: message.inventoryItems) {
                return
            }
        }

        delegate?.peer(self, didReceiveInventoryItems: message.inventoryItems)
    }

    private func handle(message: GetDataMessage) {
        log("<-- GETDATA: \(message.count) item(s)")

        for item in message.inventoryItems {
            for task in tasks {
                if task.handle(getDataInventoryItem: item) {
                    break
                }
            }
        }
    }

    private func handle(message: BlockMessage) {
        log("<-- BLOCK: \(CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeaderItem)).reversedHex)")
    }

    private func handle(message: MerkleBlockMessage) {
        log("<-- MERKLEBLOCK: \(CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeader)).reversedHex)")

        do {
            let merkleBlock = try network.merkleBlockValidator.merkleBlock(from: message)

            for task in tasks {
                if task.handle(merkleBlock: merkleBlock) {
                    break
                }
            }
        } catch {
            log("MERKLE BLOCK MESSAGE ERROR: \(error)")
        }
    }

    private func handle(message: TransactionMessage) {
        let transaction = message.transaction
        log("<-- TX: \(transaction.reversedHashHex)")

        for task in tasks {
            if task.handle(transaction: transaction) {
                break
            }
        }
    }

    private func handle(message: PingMessage) {
        log("<-- PING")

        let pongMessage = PongMessage(nonce: message.nonce)

        log("--> PONG")
        connection.send(message: pongMessage)
    }

    private func handle(message: PongMessage) {
        log("<-- PONG: \(message.nonce)")

        for task in tasks {
            if task.handle(pongNonce: message.nonce) {
                break
            }
        }
    }

    private func handle(message: RejectMessage) {
        log("<-- REJECT: \(message.message) code: 0x\(String(message.ccode, radix: 16)) reason: \(message.reason)")
    }

    private func log(_ message: String) {
        Logger.shared.log(self, "\(logName): \(message)")
    }

}

extension Peer: IPeer {

    func connect() {
        connection.connect()
    }

    func disconnect(error: Error? = nil) {
        self.connection.disconnect(error: error)
    }

    func add(task: PeerTask) {
        tasks.append(task)

        task.delegate = self
        task.requester = self

        task.start()
    }

    func isRequestingInventory(hash: Data) -> Bool {
        for task in tasks {
            if task.isRequestingInventory(hash: hash) {
                return true
            }
        }
        return false
    }

    func handleRelayedTransaction(hash: Data) -> Bool {
        for task in tasks {
            if task.handleRelayedTransaction(hash: hash) {
                return true
            }
        }
        return false
    }

    func filterLoad(bloomFilter: BloomFilter) {
        let filterLoadMessage = FilterLoadMessage(bloomFilter: bloomFilter)

        log("--> FILTERLOAD: \(bloomFilter.elementsCount) item(s)")
        connection.send(message: filterLoadMessage)
    }

    func sendMempoolMessage() {
        if !mempoolSent {
            log("--> MEMPOOL")
            connection.send(message: MemPoolMessage())
            mempoolSent = true
        }
    }

    func equalTo(_ other: IPeer?) -> Bool {
        return self.host == other?.host
    }

}

extension Peer: PeerConnectionDelegate {

    func connectionReadyForWrite(_ connection: PeerConnection) {
        if !sentVersion {
            sendVersion()
            sentVersion = true
        }
    }

    func connectionDidDisconnect(_ connection: PeerConnection, withError error: Error?) {
        connected = false
        delegate?.peerDidDisconnect(self, withError: error)
    }

    func connection(_ connection: PeerConnection, didReceiveMessage message: IMessage) {
        queue.async {
            self.handle(message: message)
        }
    }

}

extension Peer: IPeerTaskDelegate {

    func handle(completedTask task: PeerTask) {
        log("Handling completed task: \(type(of: task))")
        if let index = tasks.index(where: { $0 === task }) {
            let task = tasks.remove(at: index)
            delegate?.peer(self, didCompleteTask: task)
        }

        if tasks.isEmpty {
            delegate?.peerReady(self)
        }
    }

    func handle(failedTask task: PeerTask, error: Error) {
        log("Handling failed task: \(type(of: task))")
        connection.disconnect(error: error)
    }

    func handle(merkleBlock: MerkleBlock) {
        delegate?.handle(self, merkleBlock: merkleBlock)
    }

}

extension Peer: IPeerTaskRequester {

    func getBlocks(hashes: [Data]) {
        let message = GetBlocksMessage(protocolVersion: protocolVersion, headerHashes: hashes)

        log("--> GETBLOCKS: \(hashes.map { $0.reversedHex })")
        connection.send(message: message)
    }

    func getData(items: [InventoryItem]) {
        let message = GetDataMessage(inventoryItems: items)

        log("--> GETDATA: \(message.inventoryItems.count) items")
        connection.send(message: message)
    }

    func sendTransactionInventory(hash: Data) {
        let message = InventoryMessage(inventoryItems: [
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: hash)
        ])

        log("--> INV: \(message.inventoryItems.map { "[\($0.objectType): \($0.hash.reversedHex)]" }.joined(separator: ", "))")
        connection.send(message: message)
    }

    func send(transaction: Transaction) {
        let message = TransactionMessage(transaction: transaction)

        log("--> TX: \(message.transaction.reversedHashHex)")
        connection.send(message: message)
    }

    func ping(nonce: UInt64) {
        let message = PingMessage(nonce: nonce)

        log("--> Ping: \(message.nonce)")
        connection.send(message: message)
    }

}
