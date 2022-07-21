import Foundation
import BitcoinCore
import OpenSslKit

class TransactionMessageParser: IMessageParser {
    let id: String = "tx"

    let hasher: IDashHasher

    init(hasher: IDashHasher) {
        self.hasher = hasher
    }

    private func parseSpecialTxData(input: ByteStream, transaction: FullTransaction) -> SpecialTransaction {
        let payloadSize = input.read(VarInt.self)
        let payload = input.read(Data.self, count: Int(payloadSize.underlyingValue))

        var output = TransactionSerializer.serialize(transaction: transaction)
        output += payloadSize.data
        output += payload

        let hash = hasher.hash(data: output)
        transaction.set(hash: hash)

        return SpecialTransaction(transaction: transaction, extraPayload: payload)
    }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)
        var transaction = TransactionSerializer.deserialize(byteStream: byteStream)

        let version = Data(from: transaction.header.version)
        let isSpecialTransaction = (Int(version[0]) + Int(version[1])) > 0
        if isSpecialTransaction {
            transaction = parseSpecialTxData(input: byteStream, transaction: transaction)
        }

        return TransactionMessage(transaction: transaction, size: data.count)
    }
}
