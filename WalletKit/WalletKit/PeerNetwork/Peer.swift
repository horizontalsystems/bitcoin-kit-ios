import Foundation

class Peer {

    enum Status {
        case connecting, disconnected, ready, busy
        var connected: Bool {
            return self == .ready || self == .busy
        }
    }

    var status: Status = .disconnected

    private let protocolVersion: Int32 = 70015
    private var sentVersion: Bool = false
    private var sentVerack: Bool = false

    private let connection: PeerConnection
    private var requestedMerkleBlockHashes: [Data] = [Data]()
    private var requestedMerkleBlocks: [Data: MerkleBlock] = [Data: MerkleBlock]()
    private var relayedTransactions: [Data: Data] = [Data: Data]()

    private let queue: DispatchQueue

    weak var delegate: PeerDelegate?
    var host: String {
        return connection.host
    }
    var incompleteMerkleBlockHashes: [Data] {
        var hashes = requestedMerkleBlockHashes
        for merkleBlock in requestedMerkleBlocks.values {
            hashes.append(merkleBlock.headerHash)
        }
        return hashes
    }

    var logName: String {
        return connection.logName
    }

    init(host: String, network: NetworkProtocol = BitcoinTestNet()) {
        connection = PeerConnection(host: host, network: network)
        queue = DispatchQueue(label: "Peer: \(host)", qos: .userInitiated)

        connection.delegate = self
    }

    func connect() {
        connection.connect()
        setStatus(status: .connecting)
    }

    private func setStatus(status: Status) {
        self.status = status
        if status == .ready {
            delegate?.peerReady(self)
        }
    }

    func load(filters: [Data]) {
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

    func addFilter(filter: Data) {
        let filterAddMessage = FilterAddMessage(filter: filter)

        log("<-- FILTERADD: \(filter.hex)")
        connection.send(message: filterAddMessage)
    }

    func sendMemoryPoolMessage() {
        log("<-- MEMPOOL")
        connection.send(message: MemPoolMessage())
    }

    func sendGetHeadersMessage(headerHashes: [Data]) {
        let getHeadersMessage = GetHeadersMessage(protocolVersion: protocolVersion, headerHashes: headerHashes)

        log("<-- GETHEADERS: \(headerHashes.map { $0.reversedHex })")
        connection.send(message: getHeadersMessage)
    }

    func requestMerkleBlocks(headerHashes: [Data]) {
        for hash in headerHashes {
            requestedMerkleBlockHashes.append(hash)
        }

        let getDataMessage = GetDataMessage(inventoryItems: headerHashes.map { hash in
            InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: hash)
        })

        log("<-- GETDATA: \(getDataMessage.inventoryItems.count) items")
        setStatus(status: .busy)
        connection.send(message: getDataMessage)
    }

    func relay(transaction: Transaction) {
        relayedTransactions[transaction.dataHash] = TransactionSerializer.serialize(transaction: transaction)
        let inventoryMessage = InventoryMessage(inventoryItems: [
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: transaction.dataHash)
        ])

        log("<-- INV: \(inventoryMessage.inventoryItems) items")
        connection.send(message: inventoryMessage)
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
        delegate?.peerDidDisconnect(self, withError: error)
    }

    func connection(_ connection: PeerConnection, didReceiveMessage message: IMessage) {
        queue.async {
            self.handle(message: message)
        }
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
        if let filters = delegate?.bloomFilters {
            load(filters: filters)
        }
        sendMemoryPoolMessage()
        setStatus(status: .ready)
    }

    private func handle(message: AddressMessage) {
        log("--> ADDR: \(message.count) address(es)")
        delegate?.peer(self, didReceiveAddresses: message.addressList)
    }

    private func handle(message: InventoryMessage) {
        log("--> INV: \(message.count) item(s)")

        var items = [InventoryItem]()

        for item in message.inventoryItems {
            delegate?.runIfShouldRequest(inventoryItem: item) {
                var inventoryItem: InventoryItem
                switch item.objectType {
                case .blockMessage:
                    inventoryItem = InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: item.hash)
                default:
                    inventoryItem = item
                }

                items.append(inventoryItem)
            }
        }

        if !items.isEmpty {
            let getDataMessage = GetDataMessage(inventoryItems: items)
            log("<-- GETDATA: \(getDataMessage.inventoryItems.count) items")
            connection.send(message: getDataMessage)
        }
    }

    private func handle(message: HeadersMessage) {
        log("--> HEADERS: \(message.count) item(s)")
        delegate?.peer(self, didReceiveHeaders: message.blockHeaders)
    }

    private func handle(message: GetDataMessage) {
        log("--> GETDATA: \(message.count) item(s)")

        for item in message.inventoryItems {
            if item.objectType == .transaction, let transactionData = relayedTransactions.removeValue(forKey: item.hash) {
                let transactionMessage = TransactionMessage(transactionData: transactionData)
                log("<-- TX: \(transactionMessage.transaction.reversedHashHex)")
                connection.send(message: transactionMessage)
            }
        }
    }

    private func handle(message: BlockMessage) {
        log("--> BLOCK: \(Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeaderItem)).reversedHex)")
    }

    private func handle(message: MerkleBlockMessage) {
        log("--> MERKLEBLOCK: \(Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeader)).reversedHex)")
        do {
            let merkleBlock = try message.getMerkleBlock()

            if merkleBlock.transactionHashes.isEmpty {
                merkleBlockCompleted(merkleBlock: merkleBlock)
            } else {
                requestedMerkleBlocks[merkleBlock.headerHash] = merkleBlock
            }
        } catch {
            log("MERKLE BLOCK MESSAGE ERROR: \(error)")
        }
    }

    private func handle(message: TransactionMessage) {
        let transaction = message.transaction
        log("--> TX: \(transaction.dataHash.hex)")

        guard let merkleBlock = requestedMerkleBlocks.filter({ _, merkleBlock in merkleBlock.transactionHashes.contains(transaction.dataHash) }).first?.value else {
            delegate?.peer(self, didReceiveTransaction: transaction)
            return
        }

        merkleBlock.transactions.append(transaction)
        if merkleBlock.transactions.count == merkleBlock.transactionHashes.count {
            merkleBlockCompleted(merkleBlock: merkleBlock)
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


    private func merkleBlockCompleted(merkleBlock: MerkleBlock) {
        delegate?.peer(self, didReceiveMerkleBlock: merkleBlock)
        requestedMerkleBlocks.removeValue(forKey: merkleBlock.headerHash)

        if let index = requestedMerkleBlockHashes.index(of: merkleBlock.headerHash) {
            requestedMerkleBlockHashes.remove(at: index)
        }

        if requestedMerkleBlockHashes.isEmpty && requestedMerkleBlocks.isEmpty {
            setStatus(status: .ready)
        }
    }

}

extension Peer: Equatable {
    static func ==(lhs: Peer, rhs: Peer) -> Bool {
        return lhs.host == rhs.host
    }
}

protocol PeerDelegate: class {
    var bloomFilters: [Data] { get }
    func peerReady(_ peer: Peer)
    func peerDidDisconnect(_ peer: Peer, withError error: Bool)
    func peer(_ peer: Peer, didReceiveHeaders headers: [BlockHeader])
    func peer(_ peer: Peer, didReceiveMerkleBlock merkleBlock: MerkleBlock)
    func peer(_ peer: Peer, didReceiveTransaction transaction: Transaction)
    func peer(_ peer: Peer, didReceiveAddresses addresses: [NetworkAddress])
    func runIfShouldRequest(inventoryItem: InventoryItem, _ block: () -> Swift.Void)
}
