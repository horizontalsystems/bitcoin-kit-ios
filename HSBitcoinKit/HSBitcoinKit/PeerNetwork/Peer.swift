import Foundation
import HSCryptoKit

class Peer {

    private let protocolVersion: Int32 = 70015
    private var sentVersion: Bool = false
    private var sentVerack: Bool = false

    weak var delegate: PeerDelegate?

    private let connection: PeerConnection
    private var tasks: [PeerTask] = []

    private let queue: DispatchQueue
    private let network: INetwork

    var connected: Bool = false
    var blockHashesSynced: Bool = false
    var synced: Bool = false

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

    func connect() {
        connection.connect()
    }

    func disconnect() {
        connection.disconnect()
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

        log("--> FILTERLOAD: \(bloomFilter.size) item(s)")
        connection.send(message: filterLoadMessage)
    }

    func sendMemoryPoolMessage() {
        log("--> MEMPOOL")
        connection.send(message: MemPoolMessage())
    }

    private func sendVersionMessage() {
        let versionMessage = VersionMessage(
                version: protocolVersion,
                services: 0x00,
                timestamp: Int64(Date().timeIntervalSince1970),
                yourAddress: NetworkAddress(services: 0x00, address: connection.host, port: UInt16(connection.port)),
                myAddress: NetworkAddress(services: 0x00, address: "::ffff:127.0.0.1", port: UInt16(connection.port)),
                nonce: 0,
                userAgent: "/WalletKit:0.1.0/",
                startHeight: -1,
                relay: false
        )

        log("--> VERSION: \(versionMessage.version) --- \(versionMessage.userAgent?.value ?? "") --- \(ServiceFlags(rawValue: versionMessage.services))")
        connection.send(message: versionMessage)
    }

    private func sendVerackMessage() {
        log("--> VERACK")
        connection.send(message: VerackMessage())
    }

    private func handle(message: IMessage) {
        switch message {
        case let versionMessage as VersionMessage: handle(message: versionMessage)
        case _ as VerackMessage: handleVerackMessage()
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

        if !sentVerack {
            sendVerackMessage()
            sentVerack = true
        }

        if let startHeight = message.startHeight {
            delegate?.peer(self, didReceiveBestBlockHeight: startHeight)
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

extension Peer: PeerConnectionDelegate {

    func connectionReadyForWrite(_ connection: PeerConnection) {
        if !sentVersion {
            sendVersionMessage()
            sentVersion = true
        }
    }

    func connectionDidDisconnect(_ connection: PeerConnection, withError error: Bool) {
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

extension Peer: Equatable {
    static func ==(lhs: Peer, rhs: Peer) -> Bool {
        return lhs.host == rhs.host
    }
}

protocol PeerDelegate: class {
    func handle(_ peer: Peer, merkleBlock: MerkleBlock)
    func peerReady(_ peer: Peer)
    func peerDidConnect(_ peer: Peer)
    func peerDidDisconnect(_ peer: Peer, withError error: Bool)

    func peer(_ peer: Peer, didReceiveBestBlockHeight bestBlockHeight: Int32)
    func peer(_ peer: Peer, didCompleteTask task: PeerTask)
    func peer(_ peer: Peer, didReceiveAddresses addresses: [NetworkAddress])
    func peer(_ peer: Peer, didReceiveInventoryItems items: [InventoryItem])
}
