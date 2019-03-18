import Foundation

public protocol IMessage {
    func serialized() -> Data
}
