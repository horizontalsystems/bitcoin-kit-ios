import Foundation

struct MempoolMessage: IMessage{

    init() {}
    init(_ data: Data) {}

    func serialized() -> Data {
        return Data()
    }
}
