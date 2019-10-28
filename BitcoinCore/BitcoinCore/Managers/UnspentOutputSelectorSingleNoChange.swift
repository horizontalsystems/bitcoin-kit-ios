import Foundation

public class UnspentOutputSelectorSingleNoChange {

    private let calculator: ITransactionSizeCalculator
    private let provider: IUnspentOutputProvider

    public init(calculator: ITransactionSizeCalculator, provider: IUnspentOutputProvider) {
        self.calculator = calculator
        self.provider = provider
    }

}

extension UnspentOutputSelectorSingleNoChange: IUnspentOutputSelector {

    public func select(value: Int, feeRate: Int, outputScriptType: ScriptType = .p2pkh, changeType: ScriptType = .p2pkh, senderPay: Bool, dust: Int, pluginDataOutputSize: Int) throws -> SelectedUnspentOutputInfo {
        let unspentOutputs = provider.spendableUtxo

        guard value >= dust else {
            throw BitcoinCoreErrors.SendValueErrors.dust
        }
        guard !unspentOutputs.isEmpty else {
            throw BitcoinCoreErrors.SendValueErrors.emptyOutputs
        }

        // try to find 1 unspent output with exactly matching value
        for unspentOutput in unspentOutputs {
            let output = unspentOutput.output
            let fee = calculator.transactionSize(inputs: [output.scriptType], outputScriptTypes: [outputScriptType], pluginDataOutputSize: pluginDataOutputSize) * feeRate

            let recipientValue = senderPay ? value : value - fee
            let sentValue = senderPay ? value + fee : value

            if (sentValue <= output.value) &&                 // output.value is enough
                       (recipientValue >= dust) &&            // receivedValue won't be dust
                       (output.value - sentValue < dust) {    // no need to add change output
                return SelectedUnspentOutputInfo(unspentOutputs: [unspentOutput], recipientValue: recipientValue, changeValue: nil)
            }
        }

        throw BitcoinCoreErrors.SendValueErrors.singleNoChangeOutputNotFound
    }

}
