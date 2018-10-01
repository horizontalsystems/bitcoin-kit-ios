import Foundation

/// The pong message is sent in response to a ping message.
/// In modern protocol versions, a pong response is generated using a nonce included in the ping.
struct PongMessage: IMessage {
    /// nonce from ping
    let nonce: UInt64

    init(nonce: UInt64) {
        self.nonce = nonce
    }

    init(data: Data, network: NetworkProtocol) {
        let byteStream = ByteStream(data)
        nonce = byteStream.read(UInt64.self)
    }

    func serialized() -> Data {
        var data = Data()
        data += nonce
        return data
    }

}
