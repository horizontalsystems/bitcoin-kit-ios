import UIExtensions

public struct TransactionMessage: IMessage {
    let transaction: FullTransaction
    let size: Int

    public init(transaction: FullTransaction, size: Int) {
        self.transaction = transaction
        self.size = size
    }

    public var description: String {
        "\(transaction.header.dataHash.reversedHex)"
    }

}
