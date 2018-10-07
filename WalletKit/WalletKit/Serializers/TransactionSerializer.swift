import Foundation
import CryptoKit

class TransactionSerializer {

    static func serialize(transaction: Transaction) -> Data {
        var data = Data()

        data += UInt32(transaction.version)
        if transaction.segWit {
            data += UInt16(1)  // marker 0x00 + flag 0x01
        }
        data += VarInt(transaction.inputs.count).serialized()
        data += transaction.inputs.flatMap { TransactionInputSerializer.serialize(input: $0) }
        data += VarInt(transaction.outputs.count).serialized()
        data += transaction.outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
        if transaction.segWit {
            data += transaction.inputs.flatMap {
                TransactionWitnessSerializer.serialize(witnessData: $0.witnessData)
            }
        }
        data += UInt32(transaction.lockTime)

        return data
    }

    static func serializedForSignature(transaction: Transaction, inputIndex: Int) throws -> Data {
        var data = Data()

        data += UInt32(transaction.version)
        data += VarInt(transaction.inputs.count).serialized()
        data += try transaction.inputs.enumerated().flatMap { index, input in
            try TransactionInputSerializer.serializedForSignature(input: input, forCurrentInputSignature: inputIndex == index)
        }
        data += VarInt(transaction.outputs.count).serialized()
        data += transaction.outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
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
        transaction.dataHash = CryptoKit.sha256sha256(serialize(transaction: transaction))
        transaction.reversedHashHex = transaction.dataHash.reversedHex

        return transaction
    }

}
