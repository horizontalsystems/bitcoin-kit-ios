import BitcoinCore

public enum SectorError: Error {
    case wrongValue
    case emptyOutputs
    case notEnough(maxFee: Int)
}

class DashUnspentOutputSelector {
    private let calculator: IDashTransactionSizeCalculator

    init(calculator: IDashTransactionSizeCalculator) {
        self.calculator = calculator
    }
}

extension DashUnspentOutputSelector: IUnspentOutputSelector {

    public func select(value: Int, feeRate: Int, outputScriptType: ScriptType, changeType: ScriptType, senderPay: Bool, unspentOutputs: [UnspentOutput]) throws -> SelectedUnspentOutputInfo {
        guard value > 0 else {
            throw SelectorError.wrongValue
        }
        guard !unspentOutputs.isEmpty else {
            throw SelectorError.emptyOutputs
        }

        // Dash J dust = 1 duff * 34 + 148
        let dust = (calculator.inputSize(type: changeType) + calculator.outputSize(type: changeType)) * feeRate // fee needed for make changeOutput, we use only p2pkh for change output

        // try to find 1 unspent output with exactly matching value
        for unspentOutput in unspentOutputs {
            let output = unspentOutput.output
            let fee = calculator.transactionSize(inputs: [unspentOutput.output.scriptType], outputScriptTypes: [outputScriptType]) * feeRate
            let totalFee = senderPay ? fee : 0
            if (value + totalFee <= output.value) && (output.value - dust <= value + totalFee) {
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
        // try to remove some not needed outputs from prelast in reversed array (check indexes from count - 2 to 1)
        var indexesForRemoving = Set<Int>()
        if selectedOutputs.count > 2 {
            for index in 1..<(selectedOutputs.count - 1) {
                let outputIndex = selectedOutputs.count - index - 1 // reverse elements
                let filteredOutputs = selectedOutputs.enumerated().filter { !indexesForRemoving.contains($0.offset) && $0.offset != outputIndex }
                let totalValue = filteredOutputs.reduce(0) { $0 + $1.element.output.value }
                let scriptTypes = filteredOutputs.map { $0.element.output.scriptType }

                let lastCalculatedFee = calculator.transactionSize(inputs: scriptTypes, outputScriptTypes: [outputScriptType]) * feeRate
                let fee = senderPay ? lastCalculatedFee : 0
                if totalValue >= lastCalculatedFee && totalValue >= value + fee {
                    indexesForRemoving.insert(outputIndex)
                }
            }
        }
        // if we found unnecessary outputs, we must delete its and recalculate parameters
        if !indexesForRemoving.isEmpty {
            indexesForRemoving.sorted().reversed().forEach { i in
                selectedOutputs.remove(at: i)
            }
            totalValue = selectedOutputs.reduce(0) { $0 + $1.output.value }
            let scriptTypes = selectedOutputs.map { $0.output.scriptType }
            lastCalculatedFee = calculator.transactionSize(inputs: scriptTypes, outputScriptTypes: [outputScriptType]) * feeRate
            if senderPay {
                fee = lastCalculatedFee
            }
        }


        // if all unspentOutputs are selected and total value less than needed throw error
        if totalValue < value + fee {
            throw SelectorError.notEnough(maxFee: fee)
        }

        // if total selected unspentOutputs value more than value and fee for transaction with change output + change input -> add fee for change output and mark as need change address
        var addChangeOutput = false
        let feeWithChangeOutput = calculator.transactionSize(inputs: selectedOutputScriptTypes, outputScriptTypes: [outputScriptType, changeType]) * feeRate
        if totalValue > value + feeWithChangeOutput + (senderPay ? dust : 0) {
            lastCalculatedFee = feeWithChangeOutput
            addChangeOutput = true
        } else if senderPay {
            lastCalculatedFee = totalValue - value
        }
        return SelectedUnspentOutputInfo(unspentOutputs: selectedOutputs, totalValue: totalValue, fee: lastCalculatedFee, addChangeOutput: addChangeOutput)
    }

}
