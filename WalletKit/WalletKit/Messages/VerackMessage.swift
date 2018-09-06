import Foundation

/// The verack message is sent in reply to version.
/// This message consists of only a message header with the command string "verack".
struct VerackMessage: IMessage {

    init() {
    }

    init(data: Data) {
    }

    func serialized() -> Data {
        return Data()
    }

}
