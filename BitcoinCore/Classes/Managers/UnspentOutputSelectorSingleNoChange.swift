import Foundation

public class UnspentOutputSelectorSingleNoChange {

    private let calculator: ITransactionSizeCalculator
    private let provider: IUnspentOutputProvider
    private let dustCalculator: IDustCalculator

    public init(calculator: ITransactionSizeCalculator, provider: IUnspentOutputProvider, dustCalculator: IDustCalculator) {
        self.calculator = calculator
        self.provider = provider
        self.dustCalculator = dustCalculator
    }

}

extension UnspentOutputSelectorSingleNoChange: IUnspentOutputSelector {

    public func select(value: Int, feeRate: Int, outputScriptType: ScriptType = .p2pkh, changeType: ScriptType = .p2pkh, senderPay: Bool, pluginDataOutputSize: Int) throws -> SelectedUnspentOutputInfo {
        let unspentOutputs = provider.spendableUtxo
        let recipientOutputDust = dustCalculator.dust(type: outputScriptType)
        let changeOutputDust = dustCalculator.dust(type: changeType)

        guard unspentOutputs.allSatisfy({ !$0.output.failedToSpend }) else {
            throw BitcoinCoreErrors.SendValueErrors.singleNoChangeOutputNotFound
        }
        guard value >= recipientOutputDust else {
            throw BitcoinCoreErrors.SendValueErrors.dust
        }
        guard !unspentOutputs.isEmpty else {
            throw BitcoinCoreErrors.SendValueErrors.emptyOutputs
        }

        // try to find 1 unspent output with exactly matching value
        for unspentOutput in unspentOutputs {
            let output = unspentOutput.output
            let fee = calculator.transactionSize(previousOutputs: [output], outputScriptTypes: [outputScriptType], pluginDataOutputSize: pluginDataOutputSize) * feeRate

            let recipientValue = senderPay ? value : value - fee
            let sentValue = senderPay ? value + fee : value

            if (sentValue <= output.value) &&                                // output.value is enough
                       (recipientValue >= recipientOutputDust) &&            // receivedValue won't be dust
                       (output.value - sentValue < changeOutputDust) {       // no need to add change output
                return SelectedUnspentOutputInfo(unspentOutputs: [unspentOutput], recipientValue: recipientValue, changeValue: nil)
            }
        }

        throw BitcoinCoreErrors.SendValueErrors.singleNoChangeOutputNotFound
    }

}
