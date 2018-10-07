import Foundation
import HSCryptoKit

class TransactionOutputSerializer {

     static func serialize(output: TransactionOutput) -> Data {
        var data = Data()

        data += output.value
        let scriptLength = VarInt(output.lockingScript.count)
        data += scriptLength.serialized()
        data += output.lockingScript

        return data
    }

    static func deserialize(byteStream: ByteStream) -> TransactionOutput {
        let transactionOutput = TransactionOutput()

        transactionOutput.value = Int(byteStream.read(Int64.self))
        let scriptLength: VarInt = byteStream.read(VarInt.self)
        transactionOutput.lockingScript = byteStream.read(Data.self, count: Int(scriptLength.underlyingValue))

        return transactionOutput
    }

}
