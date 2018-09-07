import UIKit

class TransactionCell: UITableViewCell {

    @IBOutlet weak var infoLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func bind(record: TransactionRecord) {
        let fromAddress = record.from
                .map { from in
                    from.mine ? "\(from.address) (mine)" : from.address
                }
                .joined(separator: "\n")

        let toAddress = record.to
                .map { to in
                    to.mine ? "\(to.address) (mine)" : to.address
                }
                .joined(separator: "\n")

        infoLabel?.text =
                "Amount: \(record.amount)\n" +
                "Date: \(record.timestamp.map { String(describing: $0) } ?? "n/a")\n" +
                "Tx Hash: \(record.transactionHash.prefix(10))...\n" +
                "From: \(fromAddress)\n" +
                "To: \(toAddress)\n" +
                "Fee: \(record.fee)\n" +
                "Block Height: \(record.blockHeight.map { String(describing: $0) } ?? "n/a")\n"
    }

}
