import Foundation
import OpenSslKit

public class TransactionSerializer {

    static public func serialize(transaction: FullTransaction, withoutWitness: Bool = false) -> Data {
        let header = transaction.header
        var data = Data()

        data += UInt32(header.version)
        if header.segWit && !withoutWitness {
            data += UInt8(0)       // marker 0x00
            data += UInt8(1)       // flag 0x01
        }
        data += VarInt(transaction.inputs.count).serialized()
        data += transaction.inputs.flatMap { TransactionInputSerializer.serialize(input: $0) }
        data += VarInt(transaction.outputs.count).serialized()
        data += transaction.outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
        if header.segWit && !withoutWitness {
            data += transaction.inputs.flatMap {
                DataListSerializer.serialize(dataList: $0.witnessData)
            }
        }
        data += UInt32(header.lockTime)

        return data
    }

    static public func serializedForSignature(transaction: Transaction, inputsToSign: [InputToSign], outputs: [Output], inputIndex: Int, forked: Bool = false) throws -> Data {
        var data = Data()

        if forked {     // use bip143 for new transaction digest algorithm
            data += UInt32(transaction.version)

            let hashPrevouts = try inputsToSign.flatMap { input in
                try TransactionInputSerializer.serializedOutPoint(input: input)
            }
            data += Kit.sha256sha256((Data(hashPrevouts)))

            var sequences = Data()
            for inputToSign in inputsToSign {
                sequences += UInt32(inputToSign.input.sequence)
            }
            data += Kit.sha256sha256(sequences)

            let inputToSign = inputsToSign[inputIndex]

            data += try TransactionInputSerializer.serializedOutPoint(input: inputToSign)

            switch inputToSign.previousOutput.scriptType {
            case .p2sh:
                guard let script = inputToSign.previousOutput.redeemScript else {
                    throw SerializationError.noPreviousOutputScript
                }
                let scriptLength = VarInt(script.count)
                data += scriptLength.serialized()
                data += script
            default:
                data += OpCode.push(OpCode.p2pkhStart + OpCode.push(inputToSign.previousOutput.keyHash!) + OpCode.p2pkhFinish)
            }

            data += inputToSign.previousOutput.value
            data += UInt32(inputToSign.input.sequence)

            let hashOutputs = outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
            data += Kit.sha256sha256((Data(hashOutputs)))
        } else {
            data += UInt32(transaction.version)
            data += VarInt(inputsToSign.count).serialized()
            data += try inputsToSign.enumerated().flatMap { index, input in
                try TransactionInputSerializer.serializedForSignature(inputToSign: input, forCurrentInputSignature: inputIndex == index)
            }
            data += VarInt(outputs.count).serialized()
            data += outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
        }

        data += UInt32(transaction.lockTime)

        return data
    }

    static public func deserialize(data: Data) -> FullTransaction {
        return deserialize(byteStream: ByteStream(data))
    }

    static public func deserialize(byteStream: ByteStream) -> FullTransaction {
        let transaction = Transaction()
        var inputs = [Input]()
        var outputs = [Output]()

        transaction.version = Int(byteStream.read(Int32.self))
        // peek at marker
        if let marker = byteStream.last {
            transaction.segWit = marker == 0
        }
        // marker, flag
        if transaction.segWit {
            _ = byteStream.read(Int16.self)
        }

        let txInCount = byteStream.read(VarInt.self)
        for _ in 0..<Int(txInCount.underlyingValue) {
            inputs.append(TransactionInputSerializer.deserialize(byteStream: byteStream))
        }

        let txOutCount = byteStream.read(VarInt.self)
        for i in 0..<Int(txOutCount.underlyingValue) {
            let output = TransactionOutputSerializer.deserialize(byteStream: byteStream)
            output.index = i
            outputs.append(output)
        }

        if transaction.segWit {
            for i in 0..<Int(txInCount.underlyingValue) {
                inputs[i].witnessData = DataListSerializer.deserialize(byteStream: byteStream)
            }
        }

        transaction.lockTime = Int(byteStream.read(UInt32.self))

        return FullTransaction(header: transaction, inputs: inputs, outputs: outputs)
    }

}
