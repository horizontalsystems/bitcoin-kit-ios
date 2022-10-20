import OpenSslKit

class NetworkMessageSerializer: INetworkMessageSerializer {
    let magic: UInt32
    var messageSerializers = [IMessageSerializer]()

    init(magic: UInt32) {
        self.magic = magic
    }

    func add(serializer: IMessageSerializer) {
        messageSerializers.append(serializer)
    }

    func serialize(message: IMessage) throws -> Data {
        var resolvedSerializer: IMessageSerializer? = nil
        var resolvedMessageData: Data? = nil

        for serializer in messageSerializers {
            if let messageData = serializer.serialize(message: message) {
                resolvedSerializer = serializer
                resolvedMessageData = messageData
                break
            }
        }

        guard let serializer = resolvedSerializer, let messageData = resolvedMessageData else {
            throw BitcoinCoreErrors.MessageSerialization.noMessageSerializer
        }
        let checksum = Data(Kit.sha256sha256(messageData).prefix(4))
        let length = UInt32(messageData.count)

        var data = Data()
        data += magic.bigEndian
        var bytes = [UInt8](serializer.id.data(using: .ascii)!)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 12 - bytes.count))
        data += bytes
        data += length.littleEndian
        data += checksum
        data += messageData

        return data
    }

}

class GetDataMessageSerializer: IMessageSerializer {
    var id: String { return "getdata" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? GetDataMessage else {
            return nil
        }

        var data = Data()

        data += message.count.serialized()
        data += message.inventoryItems.flatMap {
            $0.serialized()
        }

        return data
    }

}

class GetBlocksMessageSerializer: IMessageSerializer {
    var id: String { return "getblocks" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? GetBlocksMessage else {
            return nil
        }

        var data = Data()
        data += message.version
        data += message.hashCount.serialized()
        for hash in message.blockLocatorHashes {
            data += hash
        }
        data += message.hashStop
        return data
    }

}

class InventoryMessageSerializer: IMessageSerializer {
    var id: String { return "inv" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? InventoryMessage else {
            return nil
        }

        var data = Data()
        data += message.count.serialized()
        data += message.inventoryItems.flatMap {
            $0.serialized()
        }
        return data
    }

}

class PingMessageSerializer: IMessageSerializer {
    var id: String { return "ping" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? PingMessage else {
            return nil
        }

        var data = Data()
        data += message.nonce
        return data
    }

}

class PongMessageSerializer: IMessageSerializer {
    var id: String { return "pong" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? PongMessage else {
            return nil
        }

        var data = Data()
        data += message.nonce
        return data
    }

}

class VersionMessageSerializer: IMessageSerializer {
    var id: String { return "version" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? VersionMessage else {
            return nil
        }

        var data = Data()
        data += message.version.littleEndian
        data += message.services.littleEndian
        data += message.timestamp.littleEndian
        data += message.yourAddress.serialized()
        data += message.myAddress?.serialized() ?? Data(count: 26)
        data += message.nonce?.littleEndian ?? UInt64(0)
        data += message.userAgent?.serialized() ?? Data([UInt8(0x00)])
        data += message.startHeight?.littleEndian ?? Int32(0)
        data += message.relay ?? false
        return data
    }

}

class VerackMessageSerializer: IMessageSerializer {
    var id: String { return "verack" }

    func serialize(message: IMessage) -> Data? {
        guard message is VerackMessage else {
            return nil
        }

        return Data()
    }

}

class MempoolMessageSerializer: IMessageSerializer {
    var id: String { return "mempool" }

    func serialize(message: IMessage) -> Data? {
        guard message is MemPoolMessage else {
            return nil
        }

        return Data()
    }

}

class TransactionMessageSerializer: IMessageSerializer {
    var id: String { return "tx" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? TransactionMessage else {
            return nil
        }

        return TransactionSerializer.serialize(transaction: message.transaction)
    }

}

class FilterLoadMessageSerializer: IMessageSerializer {
    var id: String { return "filterload" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? FilterLoadMessage else {
            return nil
        }

        let bloomFilter = message.bloomFilter

        var data = Data()
        data += VarInt(bloomFilter.filter.count).serialized()
        data += bloomFilter.filter
        data += bloomFilter.nHashFuncs
        data += bloomFilter.nTweak
        data += bloomFilter.nFlag
        return data
    }

}
