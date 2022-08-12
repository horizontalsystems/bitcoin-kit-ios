import Foundation
import BitcoinCore
import OpenSslKit

class TransactionMessageParser: IMessageParser {
    let id: String = "tx"

    let hasher: IDashHasher

    init(hasher: IDashHasher) {
        self.hasher = hasher
    }

    private func parseSpecialTxData(input: ByteStream, transaction: FullTransaction) throws -> SpecialTransaction {
        let payloadSize = input.read(VarInt.self)
        guard payloadSize.underlyingValue != 0 else {
            throw SpecialTransactionError.noExtraPayload
        }

        let payload = input.read(Data.self, count: Int(payloadSize.underlyingValue))

        var output = TransactionSerializer.serialize(transaction: transaction)
        output += payloadSize.data
        output += payload

        let hash = hasher.hash(data: output)
        transaction.set(hash: hash)

        return SpecialTransaction(transaction: transaction, extraPayload: payload, forceHashUpdate: false)
    }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)
        var transaction = TransactionSerializer.deserialize(byteStream: byteStream)

        let version = Data(from: transaction.header.version)

        // Version type is last 2 bytes of version. Special txs has none zero type and has extraPayload
        let isSpecialTransaction = (Int(version[2]) + Int(version[3])) > 0
        if isSpecialTransaction, let specialTransaction = try? parseSpecialTxData(input: byteStream, transaction: transaction) {
            transaction = specialTransaction
        }

        return TransactionMessage(transaction: transaction, size: data.count)
    }
}

extension TransactionMessageParser {
    enum SpecialTransactionError: Error {
        case noExtraPayload
    }
}
