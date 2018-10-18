import Foundation
import HSCryptoKit

class TransactionInputSerializer {

    static func serialize(input: TransactionInput) -> Data {
        var data = Data()
        data += input.previousOutputTxReversedHex.reversedData ?? Data()
        data += UInt32(input.previousOutputIndex)

        let scriptLength = VarInt(input.signatureScript.count)
        data += scriptLength.serialized()
        data += input.signatureScript
        data += UInt32(input.sequence)

        return data
    }

    static func serializedOutPoint(input: TransactionInput) throws -> Data {
        var data = Data()

        guard let output = input.previousOutput else {
            throw SerializationError.noPreviousOutput
        }

        guard let previousTransactionData = output.transaction?.dataHash else {
            throw SerializationError.noPreviousTransaction
        }

        data += previousTransactionData
        data += UInt32(output.index)

        return data
    }

    static func serializedForSignature(input: TransactionInput, forCurrentInputSignature: Bool) throws -> Data {
        var data = Data()

        guard let output = input.previousOutput else {
            throw SerializationError.noPreviousOutput
        }

        guard let previousTransactionData = output.transaction?.dataHash else {
            throw SerializationError.noPreviousTransaction
        }
        data += previousTransactionData
        data += UInt32(output.index)

        if forCurrentInputSignature {
            let scriptLength = VarInt(output.lockingScript.count)
            data += scriptLength.serialized()
            data += output.lockingScript
        } else {
            data += VarInt(0).serialized()
        }

        data += UInt32(input.sequence)

        return data
    }

    static func deserialize(byteStream: ByteStream) -> TransactionInput {
        let transactionInput = TransactionInput()

        transactionInput.previousOutputTxReversedHex = Data(byteStream.read(Data.self, count: 32).reversed()).hex
        transactionInput.previousOutputIndex = Int(byteStream.read(UInt32.self))

        let scriptLength: VarInt = byteStream.read(VarInt.self)

        transactionInput.signatureScript = byteStream.read(Data.self, count: Int(scriptLength.underlyingValue))
        transactionInput.sequence = Int(byteStream.read(UInt32.self))

        return transactionInput
    }

}
