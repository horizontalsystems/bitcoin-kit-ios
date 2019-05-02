import Foundation
import UIKit

class TransactionCell: UITableViewCell {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yyyy MMM d, HH:mm:ss")
        return formatter
    }()

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var valueLabel: UILabel?

    func bind(transaction: TransactionRecord, coinCode: String, lastBlockHeight: Int?) {
        var confirmations = "n/a"

        if let lastBlockHeight = lastBlockHeight, let blockHeight = transaction.blockHeight {
            confirmations = "\(lastBlockHeight - blockHeight + 1)"
        }

        let from = transaction.from.map { from -> String in
            var string = format(hash: from.address)
            if from.mine {
                string += " (mine)"
            }
            return string
        }

        let to = transaction.to.map { to -> String in
            var string = format(hash: to.address)
            if to.mine {
                string += " (mine)"
            }
            return string
        }

        set(string: """
                    Tx Hash:
                    Tx Index:
                    Date:
                    Amount:
                    Block:
                    Confirmations:
                    From:\((0..<from.count - 1).map { _ in "\n" }.joined())
                    To:\((0..<to.count - 1).map { _ in  "\n" }.joined())
                    """, alignment: .left, label: titleLabel)

        set(string: """
                    \(format(hash: transaction.transactionHash))
                    \(transaction.transactionIndex)
                    \(TransactionCell.dateFormatter.string(from: Date(timeIntervalSince1970: transaction.timestamp)))
                    \(transaction.amount) \(coinCode)
                    \(transaction.blockHeight.map { "# \($0)" } ?? "n/a")
                    \(confirmations)
                    \(from.joined(separator: "\n"))
                    \(to.joined(separator: "\n"))
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

    private func format(hash: String) -> String {
        guard hash.count > 22 else {
            return hash
        }

        return "\(hash[..<hash.index(hash.startIndex, offsetBy: 10)])...\(hash[hash.index(hash.endIndex, offsetBy: -10)...])"
    }

}
