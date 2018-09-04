import Foundation

protocol IMessage{
    init(_ data: Data)
    func serialized() -> Data
}
