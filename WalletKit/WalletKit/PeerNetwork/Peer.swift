import Foundation

class Peer : NSObject, StreamDelegate {
    private let protocolVersion: Int32 = 70015
    private let bufferSize = 4096

    private let host: String
    private let port: UInt32
    private let network: NetworkProtocol

    weak var delegate: PeerDelegate?

    private let queue: DispatchQueue
    private var runLoop: RunLoop?

    private var readStream: Unmanaged<CFReadStream>?
    private var writeStream: Unmanaged<CFWriteStream>?
    private var inputStream: InputStream?
    private var outputStream: OutputStream?

    private var packets: Data = Data()

    private var sentVersion: Bool = false
    private var sentVerack: Bool = false

    convenience init(network: NetworkProtocol = BitcoinTestNet()) {
        self.init(host: network.dnsSeeds[0], port: Int(network.port), network: network)
    }

    convenience init(host: String, network: NetworkProtocol = BitcoinTestNet()) {
        self.init(host: host, port: Int(network.port), network: network)
    }

    init(host: String, port: Int, network: NetworkProtocol = BitcoinTestNet()) {
        self.host = host
        self.port = UInt32(port)
        self.network = network

        queue = DispatchQueue(label: host, qos: .background)
    }

    deinit {
        disconnect()
    }

    func connect() {
        if runLoop == nil {
            queue.async {
                self.runLoop = .current
                self.connectAsync()
            }
        } else {
            print("ALREADY CONNECTED")
        }
    }

    private func connectAsync() {
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host as CFString, port, &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()

        inputStream?.delegate = self
        outputStream?.delegate = self

        inputStream?.schedule(in: .current, forMode: .commonModes)
        outputStream?.schedule(in: .current, forMode: .commonModes)

        inputStream?.open()
        outputStream?.open()

        RunLoop.current.run()
    }

    func disconnect() {
        guard readStream != nil && readStream != nil else {
            return
        }

        inputStream?.delegate = nil
        outputStream?.delegate = nil
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .current, forMode: .commonModes)
        outputStream?.remove(from: .current, forMode: .commonModes)
        readStream = nil
        writeStream = nil

        runLoop = nil

        sentVersion = false
        sentVerack = false

        log("DISCONNECTED")
    }

    func stream(_ stream: Stream, handle eventCode: Stream.Event) {
        switch stream {
        case let stream as InputStream:
            switch eventCode {
            case .openCompleted:
                log("CONNECTED")
                break
            case .hasBytesAvailable:
                readAvailableBytes(stream: stream)
            case .hasSpaceAvailable:
                break
            case .errorOccurred:
                log("IN ERROR OCCURRED")
                disconnect()
            case .endEncountered:
                log("IN CLOSED")
                disconnect()
            default:
                break
            }
        case _ as OutputStream:
            switch eventCode {
            case .openCompleted:
                break
            case .hasBytesAvailable:
                break
            case .hasSpaceAvailable:
                if !sentVersion {
                    sendVersionMessage()
                    sentVersion = true
                }
            case .errorOccurred:
                log("OUT ERROR OCCURRED")
                disconnect()
            case .endEncountered:
                log("OUT CLOSED")
                disconnect()
            default:
                break
            }
        default:
            break
        }
    }

    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let numberOfBytesRead = stream.read(buffer, maxLength: bufferSize)
            if numberOfBytesRead <= 0 {
                if let _ = stream.streamError {
                    break
                }
            } else {
                packets += Data(bytesNoCopy: buffer, count: numberOfBytesRead, deallocator: .none)
            }
        }

        while packets.count >= NetworkMessage.minimumLength {
            guard let networkMessage = NetworkMessage.deserialize(packets) else {
                return
            }

            autoreleasepool {
                packets = Data(packets.dropFirst(NetworkMessage.minimumLength + Int(networkMessage.length)))
                handle(message: networkMessage.message)
            }
        }
    }

    func load(filters: [Data]) {
        sendFilterLoadMessage(filters: filters)
    }

    func addFilter(filter: Data) {
        sendFilterAddMessage(filter: filter)
    }

    private func send(message: IMessage) {
        let message = NetworkMessage(magic: network.magic, message: message)

        let data = message.serialized()
        _ = data.withUnsafeBytes {
            outputStream?.write($0, maxLength: data.count)
        }
    }

    private func sendVersionMessage() {
        let versionMessage = VersionMessage(
                version: protocolVersion,
                services: 0x00,
                timestamp: Int64(Date().timeIntervalSince1970),
                yourAddress: NetworkAddress(services: 0x00, address: "::ffff:127.0.0.1", port: UInt16(port)),
                myAddress: NetworkAddress(services: 0x00, address: "::ffff:127.0.0.1", port: UInt16(port)),
                nonce: 0,
                userAgent: "/WalletKit:0.1.0/",
                startHeight: -1,
                relay: false
        )

        log("<-- VERSION: \(versionMessage.version) --- \(versionMessage.userAgent?.value ?? "") --- \(ServiceFlags(rawValue: versionMessage.services))")
        send(message: versionMessage)
    }

    private func sendVerackMessage() {
        log("<-- VERACK")
        send(message: VerackMessage())
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
        send(message: filterLoadMessage)
    }

    private func sendFilterAddMessage(filter: Data) {
        let filterAddMessage = FilterAddMessage(elementBytes: VarInt(filter.count), element: filter)

        log("<-- FILTERADD: \(filter.hex)")
        send(message: filterAddMessage)
    }

    func sendMemoryPoolMessage() {
        log("<-- MEMPOOL")
        send(message: MempoolMessage())
    }

    func sendGetHeadersMessage(headerHashes: [Data]) {
        let getHeadersMessage = GetBlocksMessage(version: UInt32(protocolVersion), hashCount: VarInt(headerHashes.count), blockLocatorHashes: headerHashes, hashStop: Data(count: 32))

        log("<-- GETHEADERS: \(headerHashes.map { $0.reversedHex })")
        send(message: getHeadersMessage)
    }

    func sendGetDataMessage(message: InventoryMessage) {
        log("<-- GETDATA: \(message.inventoryItems.count) item(s)")
        send(message: message)
    }

    func send(inventoryMessage: InventoryMessage) {
        log("<-- INV: \(inventoryMessage.inventoryItems.first?.hash.reversedHex ?? "UNKNOWN")")
        send(message: inventoryMessage)
    }

    func sendTransaction(transaction: Transaction) {
        log("<-- TX: \(transaction.reversedHashHex)")
        send(message: TransactionMessage(transaction: transaction))
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
        send(message: pongMessage)
    }

    private func handle(message: RejectMessage) {
        log("--> REJECT: \(message.message) code: 0x\(String(message.ccode, radix: 16)) reason: \(message.reason)")
        delegate?.peer(self, didReceiveRejectMessage: message)
    }

    private func log(_ message: String) {
        print("\(host):\(port) \(message)")
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
