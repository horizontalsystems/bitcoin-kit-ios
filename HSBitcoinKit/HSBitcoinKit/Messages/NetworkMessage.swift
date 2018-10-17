import Foundation
import HSCryptoKit

struct NetworkMessage {
    /// Magic value indicating message origin network, and used to seek to next message when stream state is unknown
    let magic: UInt32
    /// ASCII string identifying the packet content, NULL padded (non-NULL padding results in packet rejected)
    let command: String
    /// Length of payload in number of bytes
    let length: UInt32
    /// First 4 bytes of sha256(sha256(payload))
    let checksum: Data
    /// The actual data
    let message: IMessage

    static let minimumLength = 24

    private init(network: NetworkProtocol, command: String, length: UInt32, checksum: Data, message: IMessage) {
        self.magic = network.magic
        self.command = command
        self.length = length
        self.checksum = checksum
        self.message = message
    }

    init(network: NetworkProtocol, message: IMessage) {
        let serializedMessage = message.serialized()
        let checksum = Data(CryptoKit.sha256sha256(serializedMessage).prefix(4))
        let length = UInt32(serializedMessage.count)

        var resolvedCommand: String = ""
        for (command, messageClass) in NetworkMessage.messagesMap {
            if (messageClass == type(of: message)) {
                resolvedCommand = command
                break
            }
        }

        self.init(network: network, command: resolvedCommand, length: length, checksum: checksum, message: message)
    }

    func serialized() -> Data {
        var data = Data()
        data += magic.bigEndian
        var bytes = [UInt8](command.data(using: .ascii)!)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 12 - bytes.count))
        data += bytes
        data += length.littleEndian
        data += checksum
        data += message.serialized()
        return data
    }

    private static let messagesMap: [String: IMessage.Type] = [
        "addr": AddressMessage.self,
        "block": BlockMessage.self,
        "getblocks": GetBlocksMessage.self,
        "getdata": GetDataMessage.self,
        "getheaders": GetHeadersMessage.self,
        "inv": InventoryMessage.self,
        "ping": PingMessage.self,
        "pong": PongMessage.self,
        "verack": VerackMessage.self,
        "version": VersionMessage.self,
        "headers": HeadersMessage.self,
        "mempool": MemPoolMessage.self,
        "merkleblock": MerkleBlockMessage.self,
        "tx": TransactionMessage.self,
        "filterload": FilterLoadMessage.self
    ]

    static func deserialize(data: Data, network: NetworkProtocol) -> NetworkMessage? {
        let byteStream = ByteStream(data)

        let magic = byteStream.read(UInt32.self).bigEndian
        guard network.magic == magic else {
            Logger.shared.log(String(describing: NetworkMessage.self), "Wrong magic number!")
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

        let messageClass = messagesMap[command] ?? UnknownMessage.self
        let message = messageClass.init(data: payload)

        return NetworkMessage(network: network, command: command, length: length, checksum: checksum, message: message)
    }
}
