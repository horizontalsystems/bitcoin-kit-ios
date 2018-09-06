import Foundation

struct UnknownMessage: IMessage {

    init(data: Data) {
    }

    func serialized() -> Data {
        return Data()
    }

}
