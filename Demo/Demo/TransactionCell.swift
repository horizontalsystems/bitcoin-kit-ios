import UIKit
import BitcoinCore

class TransactionCell: UITableViewCell {

    @IBOutlet weak var infoLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func bind(transaction: TransactionInfo, lastBlockHeight: Int, index: Int) {
        let fromAddress = transaction.from
                .map { from in
                    from.mine ? "\(from.address) (mine)" : from.address
                }
                .joined(separator: "\n")

        let toAddress = transaction.to
                .map { to in
                    to.mine ? "\(to.address) (mine)" : to.address
                }
                .joined(separator: "\n")

        let amount = Double(transaction.amount) / 100_000_000

        infoLabel?.text =
                "Index: \(index)\n" +
                "Amount: \(amount)\n" +
                "Date: \(Date(timeIntervalSince1970: Double(transaction.timestamp)))\n" +
                "Tx Hash: \(transaction.transactionHash.prefix(10))...\n" +
                "From: \(fromAddress)\n" +
                "To: \(toAddress)\n" +
                "Block Height: \(transaction.blockHeight.map { String(describing: $0) } ?? "n/a")\n" +
                "Confirmations: \(transaction.blockHeight.map { String(describing: lastBlockHeight - $0 + 1) } ?? "n/a")"
    }

}
