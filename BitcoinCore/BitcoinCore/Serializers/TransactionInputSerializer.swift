import Foundation
import HSCryptoKit

class TransactionInputSerializer {

    static func serialize(input: Input) -> Data {
        var data = Data()
        data += input.previousOutputTxReversedHex.reversedData ?? Data()
        data += UInt32(input.previousOutputIndex)

        let scriptLength = VarInt(input.signatureScript.count)
        data += scriptLength.serialized()
        data += input.signatureScript
        data += UInt32(input.sequence)

        return data
    }

    static func serializedOutPoint(input: InputToSign) throws -> Data {
        var data = Data()
        let output = input.previousOutput

        data += output.transactionHashReversedHex.reversedData ?? Data()
        data += UInt32(output.index)

        return data
    }

    static func serializedForSignature(inputToSign: InputToSign, forCurrentInputSignature: Bool) throws -> Data {
        var data = Data()
        let output = inputToSign.previousOutput

        data += output.transactionHashReversedHex.reversedData ?? Data()
        data += UInt32(output.index)

        if forCurrentInputSignature {
            let scriptLength = VarInt(output.lockingScript.count)
            data += scriptLength.serialized()
            data += output.lockingScript
        } else {
            data += VarInt(0).serialized()
        }

        data += UInt32(inputToSign.input.sequence)

        return data
    }

    static func deserialize(byteStream: ByteStream) -> Input {
        let previousOutputTxReversedHex = Data(byteStream.read(Data.self, count: 32).reversed()).hex
        let previousOutputIndex = Int(byteStream.read(UInt32.self))
        let scriptLength: VarInt = byteStream.read(VarInt.self)
        let signatureScript = byteStream.read(Data.self, count: Int(scriptLength.underlyingValue))
        let sequence = Int(byteStream.read(UInt32.self))

        return Input(
                withPreviousOutputTxReversedHex: previousOutputTxReversedHex, previousOutputIndex: previousOutputIndex,
                script: signatureScript, sequence: sequence
        )
    }

}
