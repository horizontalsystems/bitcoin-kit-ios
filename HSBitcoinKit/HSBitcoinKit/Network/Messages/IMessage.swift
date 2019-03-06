import Foundation

protocol IMessage {
    func serialized() -> Data
}
