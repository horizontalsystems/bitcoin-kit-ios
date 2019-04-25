import Foundation

struct SelectedUnspentOutputInfo {
    let unspentOutputs: [UnspentOutput]
    let totalValue: Int                 // summary value on selected unspent unspentOutputs
    let fee: Int                        // fee for transaction with output(and maybe change output) and all selected inputs(unspent unspentOutputs) + maybe dust
    let addChangeOutput: Bool           // need to add changeOutput. Fee was calculated with change output
}

public enum SelectorError: Error {
    case wrongValue
    case emptyOutputs
    case notEnough(maxFee: Int)
}

class UnspentOutputSelector {

    let calculator: ITransactionSizeCalculator

    init(calculator: ITransactionSizeCalculator) {
        self.calculator = calculator
    }

}

extension UnspentOutputSelector: IUnspentOutputSelector {

    func select(value: Int, feeRate: Int, outputScriptType: ScriptType = .p2pkh, changeType: ScriptType = .p2pkh, senderPay: Bool, unspentOutputs: [UnspentOutput]) throws -> SelectedUnspentOutputInfo {
        guard value > 0 else {
            throw SelectorError.wrongValue
        }
        guard !unspentOutputs.isEmpty else {
            throw SelectorError.emptyOutputs
        }
        let dust = (calculator.inputSize(type: changeType) + calculator.outputSize(type: changeType)) * feeRate // fee needed for make changeOutput, we use only p2pkh for change output

        // try to find 1 unspent output with exactly matching value
        for unspentOutput in unspentOutputs {
            let output = unspentOutput.output
            let fee = calculator.transactionSize(inputs: [output.scriptType], outputScriptTypes: [outputScriptType]) * feeRate
            let totalFee = senderPay ? fee : 0
            if (value + totalFee <= output.value) && (value + totalFee + dust > output.value) {
                return SelectedUnspentOutputInfo(unspentOutputs: [unspentOutput], totalValue: output.value, fee: senderPay ? (output.value - value) : fee, addChangeOutput: false)
            }
        }

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
            throw SelectorError.notEnough(maxFee: fee)
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
