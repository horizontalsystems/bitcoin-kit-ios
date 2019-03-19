import HSCryptoKit

typealias MessageSerializers = SetOfResponsibility<IMessage, Data>

class NetworkMessageSerializer: INetworkMessageSerializer {
    let magic: UInt32
    var messageSerializers: MessageSerializers

    init(magic: UInt32, messageSerializers: MessageSerializers) {
        self.magic = magic
        self.messageSerializers = messageSerializers
    }

    func serialize(message: IMessage) -> Data? {
        guard let messageData = messageSerializers.process(id: message.command, message) else {
            print("Can't serialize \(String(describing: message))")
            return nil
        }
        let checksum = Data(CryptoKit.sha256sha256(messageData).prefix(4))
        let length = UInt32(messageData.count)

        var data = Data()
        data += magic.bigEndian
        var bytes = [UInt8](message.command.data(using: .ascii)!)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 12 - bytes.count))
        data += bytes
        data += length.littleEndian
        data += checksum
        data += messageData

        return data
    }

}

class GetDataMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "getdata" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? GetDataMessage else {
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

class GetBlocksMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "getblocks" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? GetBlocksMessage else {
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

class InventoryMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "inv" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? InventoryMessage else {
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

class PingMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "ping" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? PingMessage else {
            return nil
        }

        var data = Data()
        data += message.nonce
        return data
    }

}

class PongMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "pong" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? PongMessage else {
            return nil
        }

        var data = Data()
        data += message.nonce
        return data
    }

}

class VersionMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "version" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? VersionMessage else {
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

class VerackMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "verack" }

    override func process(_ request: IMessage) -> Data? {
        guard request is VerackMessage else {
            return nil
        }

        return Data()
    }

}

class MempoolMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "mempool" }

    override func process(_ request: IMessage) -> Data? {
        guard request is MemPoolMessage else {
            return nil
        }

        return Data()
    }

}

class TransactionMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "tx" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? TransactionMessage else {
            return nil
        }

        return TransactionSerializer.serialize(transaction: message.transaction)
    }

}

class FilterLoadMessageSerializer: ListElement<IMessage, Data> {
    override var id: String { return "filterload" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? FilterLoadMessage else {
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
