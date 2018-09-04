import Foundation

class Peer {
    private let connection: PeerConnection
    private let protocolVersion: Int32 = 70015

    private var sentVersion: Bool = false
    private var sentVerack: Bool = false

    weak var delegate: PeerDelegate?

    init(network: NetworkProtocol = BitcoinTestNet()) {
        self.connection = PeerConnection(network: network)
        connection.delegate = self
    }

    func connect() {
        connection.connect()
    }

    func load(filters: [Data]) {
        sendFilterLoadMessage(filters: filters)
    }

    func addFilter(filter: Data) {
        sendFilterAddMessage(filter: filter)
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

    private func sendFilterLoadMessage(filters: [Data]) {
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

    private func sendFilterAddMessage(filter: Data) {
        let filterAddMessage = FilterAddMessage(elementBytes: VarInt(filter.count), element: filter)

        log("<-- FILTERADD: \(filter.hex)")
        connection.send(message: filterAddMessage)
    }

    func sendMemoryPoolMessage() {
        log("<-- MEMPOOL")
        connection.send(message: MempoolMessage())
    }

    func sendGetHeadersMessage(headerHashes: [Data]) {
        let getHeadersMessage = GetBlocksMessage(version: UInt32(protocolVersion), hashCount: VarInt(headerHashes.count), blockLocatorHashes: headerHashes, hashStop: Data(count: 32))

        log("<-- GETHEADERS: \(headerHashes.map { $0.reversedHex })")
        connection.send(message: getHeadersMessage)
    }

    func sendGetDataMessage(message: InventoryMessage) {
        log("<-- GETDATA: \(message.inventoryItems.count) item(s)")
        connection.send(message: message)
    }

    func send(inventoryMessage: InventoryMessage) {
        log("<-- INV: \(inventoryMessage.inventoryItems.first?.hash.reversedHex ?? "UNKNOWN")")
        connection.send(message: inventoryMessage)
    }

    func sendTransaction(transaction: Transaction) {
        log("<-- TX: \(transaction.reversedHashHex)")
        connection.send(message: TransactionMessage(transaction: transaction))
    }

    private func log(_ message: String) {
        print("\(connection.host):\(connection.port) \(message)")
    }
}

extension Peer: PeerConnectionDelegate {
    func connectionReadyForWrite(_ connection: PeerConnection) {
        if !sentVersion {
            sendVersionMessage()
            sentVersion = true
        }
    }

    func connectionDidDisconnect(_ connection: PeerConnection) {
        delegate?.peerDidConnect(self)
    }

    func connection(_ connection: PeerConnection, didReceiveMessage message: IMessage) {
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
        delegate?.peerDidConnect(self)
    }

    private func handle(message: AddressMessage) {
        log("--> ADDR: \(message.count) address(es)")
        delegate?.peer(self, didReceiveAddressMessage: message)
    }

    private func handle(message: InventoryMessage) {
        log("--> INV: \(message.count) item(s)")
        delegate?.peer(self, didReceiveInventoryMessage: message)
    }

    private func handle(message: HeadersMessage) {
        log("--> HEADERS: \(message.count) item(s)")
        delegate?.peer(self, didReceiveHeadersMessage: message)
    }

    private func handle(message: GetDataMessage) {
        log("--> GETDATA: \(message.count) item(s)")
        delegate?.peer(self, didReceiveGetDataMessage: message)
    }

    private func handle(message: BlockMessage) {
        log("--> BLOCK: \(Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeaderItem)).reversedHex)")
    }

    private func handle(message: MerkleBlockMessage) {
        log("--> MERKLEBLOCK: \(Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: message.blockHeader)).reversedHex)")
        delegate?.peer(self, didReceiveMerkleBlockMessage: message)
    }

    private func handle(message: TransactionMessage) {
        log("--> TX: \(Crypto.sha256sha256(TransactionSerializer.serialize(transaction: message.transaction)).reversedHex)")
        delegate?.peer(self, didReceiveTransactionMessage: message)
    }

    private func handle(message: PingMessage) {
        log("--> PING")

        let pongMessage = PongMessage(nonce: message.nonce)

        log("<-- PONG")
        connection.send(message: pongMessage)
    }

    private func handle(message: RejectMessage) {
        log("--> REJECT: \(message.message) code: 0x\(String(message.ccode, radix: 16)) reason: \(message.reason)")
        delegate?.peer(self, didReceiveRejectMessage: message)
    }

}

protocol PeerDelegate : class {
    func peerDidConnect(_ peer: Peer)
    func peerDidDisconnect(_ peer: Peer)
    func peer(_ peer: Peer, didReceiveAddressMessage message: AddressMessage)
    func peer(_ peer: Peer, didReceiveHeadersMessage message: HeadersMessage)
    func peer(_ peer: Peer, didReceiveMerkleBlockMessage message: MerkleBlockMessage)
    func peer(_ peer: Peer, didReceiveTransactionMessage message: TransactionMessage)
    func peer(_ peer: Peer, didReceiveInventoryMessage message: InventoryMessage)
    func peer(_ peer: Peer, didReceiveGetDataMessage message: GetDataMessage)
    func peer(_ peer: Peer, didReceiveRejectMessage message: RejectMessage)
}
