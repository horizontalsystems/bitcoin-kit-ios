import Foundation

struct UnknownMessage: IMessage {
    let command: String = "unknown"
    let data: Data
}
