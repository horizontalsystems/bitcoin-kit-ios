import Foundation

struct FilterAddMessage: IMessage{
    let elementBytes: VarInt
    let element: Data

    init(elementBytes: VarInt, element: Data) {
        self.elementBytes = elementBytes
        self.element = element
    }

    init(_ data: Data) {
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
