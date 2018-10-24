import Foundation
import HSCryptoKit

class TransactionSerializer {

    static func serialize(transaction: Transaction, withoutWitness: Bool = false) -> Data {
        var data = Data()

        data += UInt32(transaction.version)
        if transaction.segWit && !withoutWitness {
            data += UInt8(0)       // marker 0x00
            data += UInt8(1)       // flag 0x01
        }
        data += VarInt(transaction.inputs.count).serialized()
        data += transaction.inputs.flatMap { TransactionInputSerializer.serialize(input: $0) }
        data += VarInt(transaction.outputs.count).serialized()
        data += transaction.outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
        if transaction.segWit && !withoutWitness {
            data += transaction.inputs.flatMap {
                TransactionWitnessSerializer.serialize(witnessData: $0.witnessData)
            }
        }
        data += UInt32(transaction.lockTime)

        return data
    }

    static func serializedForSignature(transaction: Transaction, inputIndex: Int, forked: Bool = false) throws -> Data {
        var data = Data()

        if forked {     // use bip143 for new transaction digest algorithm
            data += UInt32(transaction.version)

            let hashPrevouts = try transaction.inputs.flatMap { input in
                try TransactionInputSerializer.serializedOutPoint(input: input)
            }
            data += CryptoKit.sha256sha256((Data(hashPrevouts)))

            var sequences = Data()
            for input in transaction.inputs {
                sequences += UInt32(input.sequence)
            }
            data += CryptoKit.sha256sha256(sequences)

            let inputToSign = transaction.inputs[inputIndex]

            guard let previousOutput = inputToSign.previousOutput else {
                throw SerializationError.noPreviousOutput
            }
            data += try TransactionInputSerializer.serializedOutPoint(input: inputToSign)

            data += OpCode.push(OpCode.p2pkhStart + OpCode.push(previousOutput.keyHash!) + OpCode.p2pkhFinish)
            data += previousOutput.value
            data += UInt32(inputToSign.sequence)

            let hashOutputs = transaction.outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
            data += CryptoKit.sha256sha256((Data(hashOutputs)))
        } else {
            data += UInt32(transaction.version)
            data += VarInt(transaction.inputs.count).serialized()
            data += try transaction.inputs.enumerated().flatMap { index, input in
                try TransactionInputSerializer.serializedForSignature(input: input, forCurrentInputSignature: inputIndex == index)
            }
            data += VarInt(transaction.outputs.count).serialized()
            data += transaction.outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
        }

        data += UInt32(transaction.lockTime)

        return data
    }

    static func deserialize(data: Data) -> Transaction {
        return deserialize(byteStream: ByteStream(data))
    }

    static func deserialize(byteStream: ByteStream) -> Transaction {
        let transaction = Transaction()

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
            transaction.inputs.append(TransactionInputSerializer.deserialize(byteStream: byteStream))
        }

        let txOutCount = byteStream.read(VarInt.self)
        for i in 0..<Int(txOutCount.underlyingValue) {
            let output = TransactionOutputSerializer.deserialize(byteStream: byteStream)
            output.index = i
            transaction.outputs.append(output)
        }

        if transaction.segWit {
            for i in 0..<Int(txInCount.underlyingValue) {
                transaction.inputs[i].witnessData = TransactionWitnessSerializer.deserialize(byteStream: byteStream)
            }
        }

        transaction.lockTime = Int(byteStream.read(UInt32.self))
        transaction.dataHash = CryptoKit.sha256sha256(serialize(transaction: transaction, withoutWitness: true))
        transaction.reversedHashHex = transaction.dataHash.reversedHex

        return transaction
    }

}
