import Foundation
import OpenSslKit

class TransactionOutputSerializer {

     static func serialize(output: Output) -> Data {
        var data = Data()

        data += output.value
        let scriptLength = VarInt(output.lockingScript.count)
        data += scriptLength.serialized()
        data += output.lockingScript

        return data
    }

    static func deserialize(byteStream: ByteStream) -> Output {
        let value = Int(byteStream.read(Int64.self))
        let scriptLength: VarInt = byteStream.read(VarInt.self)
        let lockingScript = byteStream.read(Data.self, count: Int(scriptLength.underlyingValue))

        return Output(withValue: value, index: 0, lockingScript: lockingScript)
    }

}
