import Foundation

struct UnknownMessage: IMessage {

    init(data: Data, network: NetworkProtocol) {
    }

    func serialized() -> Data {
        return Data()
    }

}
