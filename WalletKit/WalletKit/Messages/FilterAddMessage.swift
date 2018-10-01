import Foundation

struct FilterAddMessage: IMessage {
    let elementBytes: VarInt
    let element: Data

    init(filter: Data) {
        self.elementBytes = VarInt(filter.count)
        self.element = filter
    }

    init(data: Data, network: NetworkProtocol) {
        elementBytes = 0
        element = Data()
    }

    func serialized() -> Data {
        var data = Data()
        data += elementBytes.serialized()
        data += element
        return data
    }

}
