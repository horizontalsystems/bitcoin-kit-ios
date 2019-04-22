import Foundation
import HSCryptoKit

/// The pong message is sent in response to a ping message.
/// In modern protocol versions, a pong response is generated using a nonce included in the ping.
struct PongMessage: IMessage {
    let command: String = "pong"
    /// nonce from ping
    let nonce: UInt64

}
