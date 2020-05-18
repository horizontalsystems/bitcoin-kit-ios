import UIKit
import BitcoinCore

class BalanceCell: UITableViewCell {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yyyy MMM d, HH:mm:ss")
        return formatter
    }()

    @IBOutlet weak var nameLabel: UILabel?
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var valueLabel: UILabel?
    @IBOutlet weak var errorLabel: UILabel?

    func bind(adapter: BaseAdapter) {
        let syncStateString: String
        var errorString = ""

        switch adapter.syncState {
        case .synced: syncStateString = "Synced!"
        case .apiSyncing(let transactionsFound): syncStateString = "API Syncing \(transactionsFound) txs"
        case .syncing(let progress): syncStateString = "Syncing \(Int(progress * 100))%"
        case .notSynced(let error):
            syncStateString = "Not Synced"
            errorString = "\(error)"
        }

        nameLabel?.text = adapter.name
        errorLabel?.text = errorString

        var lastBlockHeightString = "n/a"
        var lastBlockDateString = "n/a"

        if let lastBlockInfo = adapter.lastBlockInfo {
            lastBlockHeightString = "# \(lastBlockInfo.height)"

            if let timestamp = lastBlockInfo.timestamp {
                let date = Date(timeIntervalSince1970: Double(timestamp))
                lastBlockDateString = "\(BalanceCell.dateFormatter.string(from: date))"
            }
        }

        set(string: """
                    Sync state:
                    Last block:

                    Spendable balance:
                    Unspendable balance:
                    """, alignment: .left, label: titleLabel)

        set(string: """
                    \(syncStateString)
                    \(lastBlockHeightString)
                    \(lastBlockDateString)
                    \(adapter.spendableBalance.formattedAmount) \(adapter.coinCode)
                    \(adapter.unspendableBalance.formattedAmount) \(adapter.coinCode)
                    """, alignment: .right, label: valueLabel)
    }

    private func set(string: String, alignment: NSTextAlignment, label: UILabel?) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = alignment

        let attributedString = NSMutableAttributedString(string: string)
        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attributedString.length))

        label?.attributedText = attributedString
    }

}
