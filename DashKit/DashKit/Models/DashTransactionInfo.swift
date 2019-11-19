import BitcoinCore

public class DashTransactionInfo: TransactionInfo {
    public var instantTx: Bool = false

    public required init(transactionHash: String, transactionIndex: Int, from: [TransactionAddressInfo], to: [TransactionAddressInfo], amount: Int, fee: Int?, blockHeight: Int?, timestamp: Int, status: TransactionStatus) {
        super.init(transactionHash: transactionHash, transactionIndex: transactionIndex, from: from, to: to, amount: amount, fee: fee, blockHeight: blockHeight, timestamp: timestamp, status: status)
    }

}