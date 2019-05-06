import BitcoinCore

public class DashTransactionInfo: TransactionInfo {
    public var instantTx: Bool = false

    public required init(transactionHash: String, transactionIndex: Int, from: [TransactionAddressInfo], to: [TransactionAddressInfo], amount: Int, blockHeight: Int?, timestamp: Int) {
        super.init(transactionHash: transactionHash, transactionIndex: transactionIndex, from: from, to: to, amount: amount, blockHeight: blockHeight, timestamp: timestamp)
    }

}