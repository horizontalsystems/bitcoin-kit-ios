import Foundation

struct UnknownMessage: IMessage{
    init(_ data: Data) {}
    func serialized() -> Data { return Data() }
}
