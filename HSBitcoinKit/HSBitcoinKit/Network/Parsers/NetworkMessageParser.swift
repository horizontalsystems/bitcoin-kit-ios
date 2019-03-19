import HSCryptoKit

typealias MessageParsers = SetOfResponsibility<Data, IMessage>

class NetworkMessageParser: INetworkMessageParser {
    private let magic: UInt32
    var messageParsers: MessageParsers

    init(magic: UInt32, messageParsers: MessageParsers) {
        self.magic = magic
        self.messageParsers = messageParsers
    }

    func parse(data: Data) -> NetworkMessage? {
        let byteStream = ByteStream(data)

        let magic = byteStream.read(UInt32.self).bigEndian
        guard self.magic == magic else {
            return nil
        }
        let command = byteStream.read(Data.self, count: 12).to(type: String.self)
        let length = byteStream.read(UInt32.self)
        let checksum = byteStream.read(Data.self, count: 4)

        guard length <= byteStream.availableBytes else {
            return nil
        }
        let payload = byteStream.read(Data.self, count: Int(length))

        let checksumConfirm = CryptoKit.sha256sha256(payload).prefix(4)
        guard checksum == checksumConfirm else {
            return nil
        }

        let message = messageParsers.process(id: command, payload) ?? UnknownMessage(data: payload)

        return NetworkMessage(magic: magic, command: command, length: length, checksum: checksum, message: message)
    }

}

class AddressMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "addr" }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

        let count = byteStream.read(VarInt.self)

        var addressList = [NetworkAddress]()
        for _ in 0..<count.underlyingValue {
            _ = byteStream.read(UInt32.self) // Timestamp
            addressList.append(NetworkAddress(byteStream: byteStream))
        }

        return AddressMessage(addresses: addressList)
    }

}

class GetDataMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "getdata" }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

        let count = byteStream.read(VarInt.self)

        var inventoryItems = [InventoryItem]()
        for _ in 0..<count.underlyingValue {
            let type = byteStream.read(Int32.self)
            let hash = byteStream.read(Data.self, count: 32)
            let item = InventoryItem(type: type, hash: hash)
            inventoryItems.append(item)
        }

        return GetDataMessage(inventoryItems: inventoryItems)
    }

}

class InventoryMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "inv" }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

        let count = byteStream.read(VarInt.self)

        var inventoryItems = [InventoryItem]()
        var seen = Set<String>()

        for _ in 0..<Int(count.underlyingValue) {
            let item = InventoryItem(byteStream: byteStream)

            guard !seen.contains(item.hash.reversedHex) else {
                continue
            }
            seen.insert(item.hash.reversedHex)
            inventoryItems.append(item)
        }

        return InventoryMessage(inventoryItems: inventoryItems)
    }

}

class PingMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "ping" }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)
        return PingMessage(nonce: byteStream.read(UInt64.self))
    }

}

class PongMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "pong" }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)
        return PongMessage(nonce: byteStream.read(UInt64.self))
    }

}

class VerackMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "verack" }

    override func process(_ request: Data) -> IMessage? {
        return VerackMessage()
    }

}

class VersionMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "version" }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

        let version = byteStream.read(Int32.self)
        let services = byteStream.read(UInt64.self)
        let timestamp = byteStream.read(Int64.self)
        let yourAddress = NetworkAddress(byteStream: byteStream)
        if byteStream.availableBytes == 0 {
            return VersionMessage(version: version, services: services, timestamp: timestamp, yourAddress: yourAddress, myAddress: nil, nonce: nil, userAgent: nil, startHeight: nil, relay: nil)
        }
        let myAddress = NetworkAddress(byteStream: byteStream)
        let nonce = byteStream.read(UInt64.self)
        let userAgent = byteStream.read(VarString.self)
        let startHeight = byteStream.read(Int32.self)
        let relay: Bool? = byteStream.availableBytes == 0 ? nil : byteStream.read(Bool.self)

        return VersionMessage(version: version, services: services, timestamp: timestamp, yourAddress: yourAddress, myAddress: myAddress, nonce: nonce, userAgent: userAgent, startHeight: startHeight, relay: relay)
    }

}

class MemPoolMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "mempool" }

    override func process(_ request: Data) -> IMessage? {
        return MemPoolMessage()
    }

}

class MerkleBlockMessageParser: ListElement<Data, IMessage> {
    override var id: String { return  "merkleblock" }

    private let network: INetwork

    init(network: INetwork) {
        self.network = network

        super.init()
    }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

        let blockHeader = BlockHeaderSerializer.deserialize(byteStream: byteStream)
        blockHeader.headerHash = network.generateBlockHeaderHash(from: BlockHeaderSerializer.serialize(header: blockHeader))

        let totalTransactions = byteStream.read(UInt32.self)
        let numberOfHashes = byteStream.read(VarInt.self)

        var hashes = [Data]()
        for _ in 0..<numberOfHashes.underlyingValue {
            hashes.append(byteStream.read(Data.self, count: 32))
        }

        let numberOfFlags = byteStream.read(VarInt.self)

        var flags = [UInt8]()
        for _ in 0..<numberOfFlags.underlyingValue {
            flags.append(byteStream.read(UInt8.self))
        }

        return MerkleBlockMessage(blockHeader: blockHeader, totalTransactions: totalTransactions, numberOfHashes: numberOfHashes, hashes: hashes, numberOfFlags: numberOfFlags, flags: flags)
    }

}

class TransactionMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "tx" }

    override func process(_ request: Data) -> IMessage? {
        return TransactionMessage(transaction: TransactionSerializer.deserialize(data: request))
    }

}

class UnknownMessageParser: ListElement<Data, IMessage> {
    override var id: String { return "unknown" }

    override func process(_ request: Data) -> IMessage? {
        return UnknownMessage(data: request)
    }

}
