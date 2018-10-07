import Foundation
import CryptoKit

class Peer {

    private let protocolVersion: Int32 = 70015
    private var sentVersion: Bool = false
    private var sentVerack: Bool = false

    weak var delegate: PeerDelegate?

    private let connection: PeerConnection
    private var tasks: [PeerTask] = []

    private let queue: DispatchQueue
    private let network: NetworkProtocol

    var connected: Bool = false
    var headersSynced: Bool = false

    var ready: Bool {
        return connected && tasks.isEmpty
    }

    var host: String {
        return connection.host
    }

    var logName: String {
        return connection.logName
    }

    init(host: String, network: NetworkProtocol) {
        connection = PeerConnection(host: host, network: network)
        queue = DispatchQueue(label: "Peer: \(host)", qos: .userInitiated)
        self.network = network

        connection.delegate = self
    }

    func connect() {
        connection.connect()
    }

    func addFilter(filter: Data) {
        let filterAddMessage = FilterAddMessage(filter: filter)

        log("<-- FILTERADD: \(filter.hex)")
        connection.send(message: filterAddMessage)
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

        log("<-- VERSION: \(versionMessage.version) --- \(versionMessage.userAgent?.value ?? "") --- \(ServiceFlags(rawValue: versionMessage.services))")
        connection.send(message: versionMessage)
    }

    private func sendVerackMessage() {
        log("<-- VERACK")
        connection.send(message: VerackMessage())
    }

    private func load(filters: [Data]) {
        guard !filters.isEmpty else {
            return
        }

        let nTweak = arc4random_uniform(UInt32.max)
        var filter = BloomFilter(elements: filters.count, falsePositiveRate: 0.00005, randomNonce: nTweak)

        for f in filters {
            filter.insert(f)
        }

        let filterData = Data(filter.data)
        let filterLoadMessage = FilterLoadMessage(filter: filterData, nHashFuncs: filter.nHashFuncs, nTweak: nTweak, nFlags: 0)

        log("<-- FILTERLOAD: \(filters.count) item(s)")
        connection.send(message: filterLoadMessage)
    }

    private func sendMemoryPoolMessage() {
        log("<-- MEMPOOL")
        connection.send(message: MemPoolMessage())
    }

    private func handle(message: IMessage) {
        switch message {
        case let versionMessage as VersionMessage: handle(message: versionMessage)
        case _ as VerackMessage: handleVerackMessage()
        case let addressMessage as AddressMessage: handle(message: addressMessage)
        case let inventoryMessage as InventoryMessage: handle(message: inventoryMessage)
        case let headersMessage as HeadersMessage: handle(message: headersMessage)
        case let getDataMessage as GetDataMessage: handle(message: getDataMessage)
        case let blockMessage as BlockMessage: handle(message: blockMessage)
        case let merkleBlockMessage as MerkleBlockMessage: handle(message: merkleBlockMessage)
        case let transactionMessage as TransactionMessage: handle(message: transactionMessage)
        case let pingMessage as PingMessage: handle(message: pingMessage)
        case let rejectMessage as RejectMessage: handle(message: rejectMessage)
        default: break
        }
    }

    private func handle(message: VersionMessage) {
        log("--> VERSION: \(message.version) --- \(message.userAgent?.value ?? "") --- \(ServiceFlags(rawValue: message.services))")

        if !sentVerack {
            sendVerackMessage()
            sentVerack = true
        }
    }

    private func handleVerackMessage() {
        log("--> VERACK")

        if let filters = delegate?.getBloomFilters() {
            load(filters: filters)
        }
        sendMemoryPoolMessage()

        log("READY")

        connected = true

        delegate?.peerDidConnect(self)
        delegate?.peerReady(self)
    }

    private func handle(message: AddressMessage) {
        log("--> ADDR: \(message.count) address(es)")
        delegate?.peer(self, didReceiveAddresses: message.addressList)
    }

    private func handle(message: InventoryMessage) {
        log("--> INV: \(message.inventoryItems.map { "[\($0.objectType): \($0.hash.reversedHex)]" }.joined(separator: ", "))")

        var nonHandledInventoryItems = [InventoryItem]()

        for item in message.inventoryItems {
            var handled = false

            for task in tasks {
                if task.handle(inventoryItem: item) {
                    handled = true
                    break
                }
            }

            if !handled {
                nonHandledInventoryItems.append(item)
            }
        }

        if !nonHandledInventoryItems.isEmpty {
            delegate?.peer(self, didReceiveInventoryItems: nonHandledInventoryItems)
        }
    }

    private func handle(message: HeadersMessage) {
        log("--> HEADERS: \(message.count) item(s)")

        for task in tasks {
            if task.handle(blockHeaders: message.blockHeaders) {
                break
            }
        }
    }

    private func handle(message: GetDataMessage) {
        log("--> GETDATA: \(message.count) item(s)")

        for item in message.inventoryItems {
            for task in tasks {
                if task.handle(getDataInventoryItem: item) {
                    break
                }
            }
        }
    }

    private func handle(message: BlockMessage) {
        log("--> BLOCK: \(CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeaderItem)).reversedHex)")
    }

    private func handle(message: MerkleBlockMessage) {
        log("--> MERKLEBLOCK: \(CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeader)).reversedHex)")

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
        log("--> TX: \(transaction.reversedHashHex)")

        for task in tasks {
            if task.handle(transaction: transaction) {
                break
            }
        }
    }

    private func handle(message: PingMessage) {
        log("--> PING")

        let pongMessage = PongMessage(nonce: message.nonce)

        log("<-- PONG")
        connection.send(message: pongMessage)
    }

    private func handle(message: RejectMessage) {
        log("--> REJECT: \(message.message) code: 0x\(String(message.ccode, radix: 16)) reason: \(message.reason)")
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

    func handle(task: PeerTask) {
        if let index = tasks.index(where: { $0 === task }) {
            let task = tasks.remove(at: index)
            delegate?.peer(self, didHandleTask: task)
        }

        if tasks.isEmpty {
            delegate?.peerReady(self)
        }
    }

}

extension Peer: IPeerTaskRequester {

    func requestHeaders(hashes: [Data]) {
        let message = GetHeadersMessage(protocolVersion: protocolVersion, headerHashes: hashes)

        log("<-- GETHEADERS: \(hashes.map { $0.reversedHex })")
        connection.send(message: message)
    }

    func requestData(items: [InventoryItem]) {
        let message = GetDataMessage(inventoryItems: items)

        log("<-- GETDATA: \(message.inventoryItems.count) items")
        connection.send(message: message)
    }

    func sendTransactionInventory(hash: Data) {
        let message = InventoryMessage(inventoryItems: [
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: hash)
        ])

        log("<-- INV: \(message.inventoryItems.map { "[\($0.objectType): \($0.hash.reversedHex)]" }.joined(separator: ", "))")
        connection.send(message: message)
    }

    func send(transaction: Transaction) {
        let message = TransactionMessage(transaction: transaction)

        log("<-- TX: \(message.transaction.reversedHashHex)")
        connection.send(message: message)
    }

}

extension Peer: Equatable {
    static func ==(lhs: Peer, rhs: Peer) -> Bool {
        return lhs.host == rhs.host
    }
}

protocol PeerDelegate: class {
    func getBloomFilters() -> [Data]

    func peerReady(_ peer: Peer)
    func peerDidConnect(_ peer: Peer)
    func peerDidDisconnect(_ peer: Peer, withError error: Bool)

    func peer(_ peer: Peer, didHandleTask task: PeerTask)

    func peer(_ peer: Peer, didReceiveAddresses addresses: [NetworkAddress])
    func peer(_ peer: Peer, didReceiveInventoryItems items: [InventoryItem])
}
