import UIKit

class TransactionCell: UITableViewCell {

    @IBOutlet weak var infoLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func bind(record: TransactionRecord) {
        infoLabel?.text =
                "Amount: \(record.amount)\n" +
                "Date: \(record.timestamp.map { String(describing: $0) } ?? "n/a")\n" +
                "Tx Hash: \(record.transactionHash.prefix(10))...\n" +
                "From: \(record.from.first ?? "n/a")\n" +
                "To: \(record.to.first ?? "n/a")\n" +
                "Fee: \(record.fee)\n" +
                "Block Height: \(record.blockHeight.map { String(describing: $0) } ?? "n/a")\n"
    }

}
