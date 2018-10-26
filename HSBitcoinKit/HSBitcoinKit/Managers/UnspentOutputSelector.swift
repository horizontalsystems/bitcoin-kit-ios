import Foundation

struct SelectedUnspentOutputInfo {
    let outputs: [TransactionOutput]
    let totalValue: Int                 // summary value on selected unspent outputs
    let fee: Int                        // fee for transaction with output(and maybe change output) and all selected inputs(unspent outputs) + maybe dust
    let addChangeOutput: Bool           // need to add changeOutput. Fee was calculated with change output
}

class UnspentOutputSelector {
    enum SelectorError: Error {
        case wrongValue
        case emptyOutputs
        case notEnough
    }

    let calculator: ITransactionSizeCalculator

    init(calculator: ITransactionSizeCalculator) {
        self.calculator = calculator
    }

}

extension UnspentOutputSelector: IUnspentOutputSelector {

    func select(value: Int, feeRate: Int, outputType: ScriptType = .p2pkh, changeType: ScriptType = .p2pkh, senderPay: Bool, outputs: [TransactionOutput]) throws -> SelectedUnspentOutputInfo {
        guard value > 0 else {
            throw SelectorError.wrongValue
        }
        guard !outputs.isEmpty else {
            throw SelectorError.emptyOutputs
        }
        let dust = (calculator.inputSize(type: changeType) + calculator.outputSize(type: changeType)) * feeRate // fee needed for make changeOutput, we use only p2pkh for change output

        // try to find 1 unspent output with exactly matching value
        for output in outputs {
            let fee = calculator.transactionSize(inputs: [output.scriptType], outputs: [outputType]) * feeRate
            let totalFee = senderPay ? fee : 0
            if (value + totalFee <= output.value) && (value + totalFee + dust > output.value) {
                return SelectedUnspentOutputInfo(outputs: [output], totalValue: output.value, fee: senderPay ? (output.value - value) : fee, addChangeOutput: false)
            }
        }

        let sortedOutputs = outputs.sorted(by: { lhs, rhs in lhs.value < rhs.value })

        // select outputs with least value until we get needed value
        var selectedOutputs = [TransactionOutput]()
        var selectedOutputTypes = [ScriptType]()
        var totalValue = 0

        var fee = 0
        var lastCalculatedFee = 0

        for output in sortedOutputs {
            lastCalculatedFee = calculator.transactionSize(inputs: selectedOutputTypes, outputs: [outputType]) * feeRate
            if senderPay {
                fee = lastCalculatedFee
            }
            if totalValue >= value + fee {
                break
            }
            selectedOutputs.append(output)
            selectedOutputTypes.append(output.scriptType)
            totalValue += output.value
        }

        // if all outputs are selected and total value less than needed throw error
        if totalValue < value + fee {
            throw UnspentOutputSelector.SelectorError.notEnough
        }

        // if total selected outputs value more than value and fee for transaction with change output + change input -> add fee for change output and mark as need change address
        var addChangeOutput = false
        if totalValue > value + lastCalculatedFee + (senderPay ? dust : 0) {
            lastCalculatedFee = calculator.transactionSize(inputs: selectedOutputTypes, outputs: [outputType, changeType]) * feeRate
            addChangeOutput = true
        } else if senderPay {
            lastCalculatedFee = totalValue - value
        }

        return SelectedUnspentOutputInfo(outputs: selectedOutputs, totalValue: totalValue, fee: lastCalculatedFee, addChangeOutput: addChangeOutput)
    }

}
