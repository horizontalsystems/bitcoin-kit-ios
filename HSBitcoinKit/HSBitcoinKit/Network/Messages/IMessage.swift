import Foundation

protocol IMessage {
    init(data: Data)
    func serialized() -> Data
}
