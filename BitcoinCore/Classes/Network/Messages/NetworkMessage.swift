import Foundation

struct NetworkMessage {
    static let minimumLength = 24
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
}
