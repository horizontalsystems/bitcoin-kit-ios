import Foundation
import UIKit
import Hodler

class TransactionCell: UITableViewCell {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yyyy MMM d, HH:mm:ss")
        return formatter
    }()

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var valueLabel: UILabel?
    @IBOutlet weak var transactionTypeLabel: UILabel?
    private let coinRate: Decimal = pow(10, 8)

    func bind(transaction: TransactionRecord, coinCode: String, lastBlockHeight: Int?) {
        var confirmations = "n/a"

        if let lastBlockHeight = lastBlockHeight, let blockHeight = transaction.blockHeight {
            confirmations = "\(lastBlockHeight - blockHeight + 1)"
        }

        let from = transaction.from.map { from -> String in
            var string = from.address.flatMap { format(hash: $0) } ?? "Unknown address"
            if from.mine {
                string += "(mine)"
            }
            if let value = from.value {
                string += "(\((Decimal(value) / coinRate).formattedAmount))"
            }
            return string
        }

        let to = transaction.to.map { to -> String in
            var string = to.address.flatMap { format(hash: $0) } ?? "Unknown address"
            if to.mine {
                string += "(mine)"
            }
            if to.changeOutput {
                string += "(change)"
            }
            if let value = to.value {
                string += "(\((Decimal(value) / coinRate).formattedAmount))"
            }
            if let pluginId = to.pluginId, let pluginData = to.pluginData, pluginId == HodlerPlugin.id, let hodlerData = pluginData as? HodlerOutputData {
                string += "\nLocked Until: \(TransactionCell.dateFormatter.string(from: Date(timeIntervalSince1970: Double(hodlerData.approximateUnlockTime!))))  <-"
                string += "\nOriginal: \(format(hash: hodlerData.addressString))  <-"
            }
            return string
        }

        set(string: """
                    Tx Hash:
                    Tx Status:
                    Tx Index:
                    Date:
                    Type:
                    Amount:
                    Fee:
                    Block:
                    ConflictingHash:
                    Confirmations:
                    \(from.map { _ in "From:" }.joined(separator: "\n"))
                    \(transaction.to.map { "To:\(String(repeating: "\n", count: TransactionCell.rowsCount(address: $0)))" }.joined(separator: ""))
                    """, alignment: .left, label: titleLabel)

        set(string: """
                    \(format(hash: transaction.transactionHash))
                    \(transaction.status)
                    \(transaction.transactionIndex)
                    \(TransactionCell.dateFormatter.string(from: transaction.date))
                    \(transaction.type.rawValue)
                    \(transaction.amount.formattedAmount) \(coinCode)
                    \(transaction.fee?.formattedAmount ?? "") \(coinCode)
                    \(transaction.blockHeight.map { "# \($0)" } ?? "n/a")
                    \(format(hash: transaction.conflictingHash ?? "n/a"))
                    \(confirmations)
                    \(from.joined(separator: "\n"))
                    \(to.joined(separator: "\n"))
                    """, alignment: .right, label: valueLabel)
        
        transactionTypeLabel?.isHidden = transaction.transactionExtraType == nil
        transactionTypeLabel?.text = transaction.transactionExtraType
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

        return "\(hash[..<hash.index(hash.startIndex, offsetBy: 8)])...\(hash[hash.index(hash.endIndex, offsetBy: -2)...])"
    }

}

extension TransactionCell {
    
    static func rowsCount(address: TransactionInputOutput) -> Int {
        var rowsCount = 1

        if let pluginId = address.pluginId, pluginId == HodlerPlugin.id {
            rowsCount += 2
        }
        
        return rowsCount
    }

    static func rowHeight(for transaction: TransactionRecord) -> Int {
        let addressRowsCount = transaction.to.reduce(0) { $0 + rowsCount(address: $1) } + transaction.from.count
        var height = (addressRowsCount + 10) * 18 + 30

        if transaction.transactionExtraType != nil {
            height += 18
        }

        return height
    }

}
