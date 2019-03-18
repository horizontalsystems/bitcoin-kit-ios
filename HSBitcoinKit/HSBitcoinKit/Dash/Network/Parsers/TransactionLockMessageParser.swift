import HSCryptoKit

// todo identical code with transactionMessageParser
class TransactionLockMessageParser: ListElement<Data, IMessage> {

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

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
        transaction.dataHash = CryptoKit.sha256sha256(TransactionSerializer.serialize(transaction: transaction, withoutWitness: true))
        transaction.reversedHashHex = transaction.dataHash.reversedHex

        return TransactionMessage(transaction: transaction)
    }

}
