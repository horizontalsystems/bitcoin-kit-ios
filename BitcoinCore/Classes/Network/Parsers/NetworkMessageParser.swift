import OpenSslKit
import UIExtensions

class NetworkMessageParser: INetworkMessageParser {
    private let magic: UInt32
    private var messageParsers = [String: IMessageParser]()

    init(magic: UInt32) {
        self.magic = magic
    }

    func add(parser: IMessageParser) {
        messageParsers[parser.id] = parser
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

        let checksumConfirm = Kit.sha256sha256(payload).prefix(4)
        guard checksum == checksumConfirm else {
            return nil
        }

        let message = messageParsers[command]?.parse(data: payload) ?? UnknownMessage(data: payload)

        return NetworkMessage(magic: magic, command: command, length: length, checksum: checksum, message: message)
    }

}

class AddressMessageParser: IMessageParser {
    var id: String { return "addr" }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let count = byteStream.read(VarInt.self)

        var addressList = [NetworkAddress]()
        for _ in 0..<count.underlyingValue {
            _ = byteStream.read(UInt32.self) // Timestamp
            addressList.append(NetworkAddress(byteStream: byteStream))
        }

        return AddressMessage(addresses: addressList)
    }

}

class GetDataMessageParser: IMessageParser {
    var id: String { return "getdata" }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

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

class InventoryMessageParser: IMessageParser {
    var id: String { return "inv" }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

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

class PingMessageParser: IMessageParser {
    var id: String { return "ping" }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)
        return PingMessage(nonce: byteStream.read(UInt64.self))
    }

}

class PongMessageParser: IMessageParser {
    var id: String { return "pong" }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)
        return PongMessage(nonce: byteStream.read(UInt64.self))
    }

}

class VerackMessageParser: IMessageParser {
    var id: String { return "verack" }

    func parse(data: Data) -> IMessage {
        return VerackMessage()
    }

}

class VersionMessageParser: IMessageParser {
    var id: String { return "version" }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

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

class MemPoolMessageParser: IMessageParser {
    var id: String { return "mempool" }

    func parse(data: Data) -> IMessage {
        return MemPoolMessage()
    }

}

class MerkleBlockMessageParser: IMessageParser {
    var id: String { return  "merkleblock" }

    private let blockHeaderParser: IBlockHeaderParser

    init(blockHeaderParser: IBlockHeaderParser) {
        self.blockHeaderParser = blockHeaderParser
    }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let blockHeader = blockHeaderParser.parse(byteStream: byteStream)

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

class TransactionMessageParser: IMessageParser {
    var id: String { return "tx" }

    func parse(data: Data) -> IMessage {
        return TransactionMessage(transaction: TransactionSerializer.deserialize(data: data), size: data.count)
    }

}

class UnknownMessageParser: IMessageParser {
    var id: String { return "unknown" }

    func parse(data: Data) -> IMessage {
        return UnknownMessage(data: data)
    }

}
