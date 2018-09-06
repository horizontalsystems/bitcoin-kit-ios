import Foundation

class TransactionSerializer {

    static func serialize(transaction: Transaction) -> Data {
        var data = Data()

        data += UInt32(transaction.version)
        data += VarInt(transaction.inputs.count).serialized()
        data += transaction.inputs.flatMap { TransactionInputSerializer.serialize(input: $0) }
        data += VarInt(transaction.outputs.count).serialized()
        data += transaction.outputs.flatMap { TransactionOutputSerializer.serialize(output: $0) }
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

        transaction.lockTime = Int(byteStream.read(UInt32.self))
        transaction.reversedHashHex = Crypto.sha256sha256(serialize(transaction: transaction)).reversedHex

        return transaction
    }

}
