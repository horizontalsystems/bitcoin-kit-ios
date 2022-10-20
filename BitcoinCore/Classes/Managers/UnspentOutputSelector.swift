import Foundation

public struct SelectedUnspentOutputInfo {
    public let unspentOutputs: [UnspentOutput]
    public let recipientValue: Int              // amount to set to recipient output
    public let changeValue: Int?                // amount to set to change output. No change output if nil

    public init(unspentOutputs: [UnspentOutput], recipientValue: Int, changeValue: Int?) {
        self.unspentOutputs = unspentOutputs
        self.recipientValue = recipientValue
        self.changeValue = changeValue
    }
}

public class UnspentOutputSelector {

    private let calculator: ITransactionSizeCalculator
    private let provider: IUnspentOutputProvider
    private let dustCalculator: IDustCalculator
    private let outputsLimit: Int?

    public init(calculator: ITransactionSizeCalculator, provider: IUnspentOutputProvider, dustCalculator: IDustCalculator, outputsLimit: Int? = nil) {
        self.calculator = calculator
        self.provider = provider
        self.dustCalculator = dustCalculator
        self.outputsLimit = outputsLimit
    }

}

extension UnspentOutputSelector: IUnspentOutputSelector {

    public func select(value: Int, feeRate: Int, outputScriptType: ScriptType = .p2pkh, changeType: ScriptType = .p2pkh, senderPay: Bool, pluginDataOutputSize: Int) throws -> SelectedUnspentOutputInfo {
        let unspentOutputs = provider.spendableUtxo
        let recipientOutputDust = dustCalculator.dust(type: outputScriptType)
        let changeOutputDust = dustCalculator.dust(type: changeType)

        // check if value is not dust. recipientValue may be less, but not more
        guard value >= recipientOutputDust else {
            throw BitcoinCoreErrors.SendValueErrors.dust
        }
        guard !unspentOutputs.isEmpty else {
            throw BitcoinCoreErrors.SendValueErrors.emptyOutputs
        }

        let sortedOutputs = unspentOutputs.sorted(by: { lhs, rhs in
            (lhs.output.failedToSpend && !rhs.output.failedToSpend) || (
                    lhs.output.failedToSpend == rhs.output.failedToSpend &&  lhs.output.value < rhs.output.value
            )
        })

        // select unspentOutputs with least value until we get needed value
        var selectedOutputs = [UnspentOutput]()
        var totalValue = 0
        var recipientValue = 0
        var sentValue = 0
        var fee = 0

        for unspentOutput in sortedOutputs {
            selectedOutputs.append(unspentOutput)
            totalValue += unspentOutput.output.value

            if let outputsLimit = outputsLimit {
                if (selectedOutputs.count > outputsLimit) {
                    guard let outputValueToExclude = selectedOutputs.first?.output.value else {
                        continue
                    }
                    selectedOutputs.remove(at: 0)
                    totalValue -= outputValueToExclude
                }
            }
            fee = calculator.transactionSize(previousOutputs: selectedOutputs.map { $0.output }, outputScriptTypes: [outputScriptType], pluginDataOutputSize: pluginDataOutputSize) * feeRate

            recipientValue = senderPay ? value : value - fee
            sentValue = senderPay ? value + fee : value

            if sentValue <= totalValue {      // totalValue is enough
                if recipientValue >= recipientOutputDust {   // receivedValue won't be dust
                    break
                } else {
                    // Here senderPay is false, because otherwise "dust" exception would throw far above.
                    // Adding more UTXOs will make fee even greater, making recipientValue even less and dust anyway
                    throw BitcoinCoreErrors.SendValueErrors.dust
                }
            }
        }

        // if all unspentOutputs are selected and total value less than needed, then throw error
        if totalValue < sentValue {
            throw BitcoinCoreErrors.SendValueErrors.notEnough
        }

        let changeOutputHavingTransactionFee = calculator.transactionSize(previousOutputs: selectedOutputs.map { $0.output }, outputScriptTypes: [outputScriptType, changeType], pluginDataOutputSize: pluginDataOutputSize) * feeRate
        let withChangeRecipientValue = senderPay ? value : value - changeOutputHavingTransactionFee
        let withChangeSentValue = senderPay ? value + changeOutputHavingTransactionFee : value
        // if selected UTXOs total value >= recipientValue(toOutput value) + fee(for transaction with change output) + dust(minimum changeOutput value)
        if totalValue >= withChangeRecipientValue + changeOutputHavingTransactionFee + changeOutputDust {
            // totalValue is too much, we must have change output
            guard withChangeRecipientValue >= recipientOutputDust else {
                throw BitcoinCoreErrors.SendValueErrors.dust
            }

            return SelectedUnspentOutputInfo(unspentOutputs: selectedOutputs, recipientValue: withChangeRecipientValue, changeValue: totalValue - withChangeSentValue)
        }

        // No change needed
        return SelectedUnspentOutputInfo(unspentOutputs: selectedOutputs, recipientValue: recipientValue, changeValue: nil)
    }

}
