import Foundation

class Peer {
    private let protocolVersion: Int32 = 70015

    private var sentVersion: Bool = false
    private var sentVerack: Bool = false

    private let connection: PeerConnection
    private var requestedMerkleBlocks: [Data: MerkleBlock?] = [Data: MerkleBlock?]()
    private var relayedTransactions: [Data: Data] = [Data: Data]()

    weak var delegate: PeerDelegate?

    init(network: NetworkProtocol = BitcoinTestNet()) {
        self.connection = PeerConnection(network: network)
        connection.delegate = self
    }

    func connect() {
        connection.connect()
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
        for hash in headerHashes {
            requestedMerkleBlocks[hash] = nil
        }

        let getHeadersMessage = GetHeadersMessage(protocolVersion: protocolVersion, headerHashes: headerHashes)

        log("<-- GETHEADERS: \(headerHashes.map { $0.reversedHex })")
        connection.send(message: getHeadersMessage)
    }

    func requestMerkleBlocks(headerHashes: [Data]) {
        let inventoryMessage = GetDataMessage(inventoryItems: headerHashes.map { hash in
            InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: hash)
        })

        connection.send(message: inventoryMessage)
    }

    func relay(transaction: Transaction) {
        log("<-- TX: \(transaction.reversedHashHex)")

        let transactionData = TransactionSerializer.serialize(transaction: transaction)
        let transactionHash = Crypto.sha256sha256(transactionData)
        relayedTransactions[transactionHash] = transactionData

        let inventoryMessage = InventoryMessage(inventoryItems: [
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: transactionHash)
        ])

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
    }

    private func handle(message: InventoryMessage) {
        log("--> INV: \(message.count) item(s)")

        var items = [InventoryItem]()

        for item in message.inventoryItems {
            if let delegate = delegate, delegate.shouldRequest(inventoryItem: item) {
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
            print("searching: \(item.hash.hex); count: \(relayedTransactions.count)")
            if item.objectType == .transaction, let transactionData = relayedTransactions.removeValue(forKey: item.hash) {
                let transactionMessage = TransactionMessage(transactionData: transactionData)
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
                print("TX COUNT: \(merkleBlock.transactionHashes.count)")
            }
        } catch {
            print("MERKLE BLOCK MESSAGE ERROR: \(error)")
        }
    }

    private func handle(message: TransactionMessage) {
        let transaction = message.transaction
        let txHash = Crypto.sha256sha256(TransactionSerializer.serialize(transaction: transaction))
        log("--> TX: \(txHash.reversedHex)")

        if var merkleBlock = requestedMerkleBlocks.values.filter({ merkleBlock in merkleBlock?.transactionHashes.contains(txHash) ?? false }).first.flatMap({ $0 }) {
            merkleBlock.transactions.append(transaction)

            if merkleBlock.transactions.count == merkleBlock.transactionHashes.count {
                merkleBlockCompleted(merkleBlock: merkleBlock)
            }
        } else {
            delegate?.peer(self, didReceiveTransaction: transaction)
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
//        if requestedMerkleBlocks.isEmpty() {
//            isFree = true
//        }
    }

}

protocol PeerDelegate: class {
    func peerDidConnect(_ peer: Peer)
    func peerDidDisconnect(_ peer: Peer)
    func peer(_ peer: Peer, didReceiveHeaders headers: [BlockHeader])
    func peer(_ peer: Peer, didReceiveMerkleBlock merkleBlock: MerkleBlock)
    func peer(_ peer: Peer, didReceiveTransaction transaction: Transaction)
    func shouldRequest(inventoryItem: InventoryItem) -> Bool
}
