import Foundation

public struct SelectedUnspentOutputInfo {
    public let unspentOutputs: [UnspentOutput]
    public let totalValue: Int                 // summary value on selected unspent unspentOutputs
    public let fee: Int                        // fee for transaction with output(and maybe change output) and all selected inputs(unspent unspentOutputs) + maybe dust
    public let addChangeOutput: Bool           // need to add changeOutput. Fee was calculated with change output

    public init(unspentOutputs: [UnspentOutput], totalValue: Int, fee: Int, addChangeOutput: Bool) {
        self.unspentOutputs = unspentOutputs
        self.totalValue = totalValue
        self.fee = fee
        self.addChangeOutput = addChangeOutput
    }
}

public class UnspentOutputSelector {

    private let calculator: ITransactionSizeCalculator
    private let provider: IUnspentOutputProvider
    private let outputsLimit: Int?

    public init(calculator: ITransactionSizeCalculator, provider: IUnspentOutputProvider, outputsLimit: Int? = nil) {
        self.calculator = calculator
        self.provider = provider
        self.outputsLimit = outputsLimit
    }

}

extension UnspentOutputSelector: IUnspentOutputSelector {

    public func select(value: Int, feeRate: Int, outputScriptType: ScriptType = .p2pkh, changeType: ScriptType = .p2pkh, senderPay: Bool) throws -> SelectedUnspentOutputInfo {
        let unspentOutputs = provider.allUnspentOutputs

        guard value > 0 else {
            throw BitcoinCoreErrors.UnspentOutputSelection.wrongValue
        }
        guard !unspentOutputs.isEmpty else {
            throw BitcoinCoreErrors.UnspentOutputSelection.emptyOutputs
        }
        let dust = (calculator.inputSize(type: changeType) + calculator.outputSize(type: changeType)) * feeRate // fee needed for make changeOutput, we use only p2pkh for change output

        let sortedOutputs = unspentOutputs.sorted(by: { lhs, rhs in lhs.output.value < rhs.output.value })

        // select unspentOutputs with least value until we get needed value
        var selectedOutputs = [UnspentOutput]()
        var selectedOutputScriptTypes = [ScriptType]()
        var totalValue = 0

        var fee = 0
        var lastCalculatedFee = 0

        for unspentOutput in sortedOutputs {
            selectedOutputs.append(unspentOutput)
            selectedOutputScriptTypes.append(unspentOutput.output.scriptType)
            totalValue += unspentOutput.output.value

            if let outputsLimit = outputsLimit {
                if (selectedOutputs.count > outputsLimit) {
                    guard let outputValueToExclude = selectedOutputs.first?.output.value else {
                        continue
                    }
                    selectedOutputs.remove(at: 0)
                    selectedOutputScriptTypes.remove(at: 0)
                    totalValue -= outputValueToExclude
                }
            }
            lastCalculatedFee = calculator.transactionSize(inputs: selectedOutputScriptTypes, outputScriptTypes: [outputScriptType]) * feeRate
            if senderPay {
                fee = lastCalculatedFee
            }
            if totalValue >= lastCalculatedFee && totalValue >= value + fee {
                break
            }
        }

        // if all unspentOutputs are selected and total value less than needed throw error
        if totalValue < value + fee {
            throw BitcoinCoreErrors.UnspentOutputSelection.notEnough(maxFee: fee)
        }

        // if total selected unspentOutputs value more than value and fee for transaction with change output + change input -> add fee for change output and mark as need change address
        var addChangeOutput = false
        if totalValue > value + lastCalculatedFee + (senderPay ? dust : 0) {
            lastCalculatedFee = calculator.transactionSize(inputs: selectedOutputScriptTypes, outputScriptTypes: [outputScriptType, changeType]) * feeRate
            addChangeOutput = true
        } else if senderPay {
            lastCalculatedFee = totalValue - value
        }
        return SelectedUnspentOutputInfo(unspentOutputs: selectedOutputs, totalValue: totalValue, fee: lastCalculatedFee, addChangeOutput: addChangeOutput)
    }

}
