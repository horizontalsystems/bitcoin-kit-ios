public protocol IBaseTransactionInfoConverter {
    func transactionInfo<T: TransactionInfo>(fromTransaction transactionForInfo: FullTransactionForInfo) -> T
}

public class BaseTransactionInfoConverter: IBaseTransactionInfoConverter {
    private let pluginManager: IPluginManager

    public init(pluginManager: IPluginManager) {
        self.pluginManager = pluginManager
    }

    public func transactionInfo<T: TransactionInfo>(fromTransaction transactionForInfo: FullTransactionForInfo) -> T {
        var totalMineInput: Int = 0
        var totalMineOutput: Int = 0
        var fromAddresses = [TransactionAddressInfo]()
        var toAddresses = [TransactionAddressInfo]()
        var hasOnlyMyInputs = true
        let transaction = transactionForInfo.transactionWithBlock.transaction
        let transactionTimestamp = transaction.timestamp

        for inputWithPreviousOutput in transactionForInfo.inputsWithPreviousOutputs {
            var mine = false

            if let previousOutput = inputWithPreviousOutput.previousOutput, previousOutput.publicKeyPath != nil {
                totalMineInput += previousOutput.value
                mine = true
            } else {
                hasOnlyMyInputs = false
            }

            if let address = inputWithPreviousOutput.input.address {
                fromAddresses.append(TransactionAddressInfo(address: address, mine: mine, pluginData: nil))
            }
        }

        for output in transactionForInfo.outputs {
            var mine = false

            if output.publicKeyPath != nil {
                totalMineOutput += output.value
                mine = true
            }

            if let address = output.address {
                toAddresses.append(TransactionAddressInfo(address: address, mine: mine, pluginData: pluginManager.parsePluginData(from: output, transactionTimestamp: transactionTimestamp)))
            }
        }

        var amount = totalMineOutput - totalMineInput

        var resolvedFee: Int? = nil
        if hasOnlyMyInputs {
            let fee = totalMineInput - transactionForInfo.outputs.reduce(0) { totalOutput, output in totalOutput + output.value }
            amount += fee
            resolvedFee = fee
        }

        return T(
                transactionHash: transaction.dataHash.reversedHex,
                transactionIndex: transaction.order,
                from: fromAddresses,
                to: toAddresses,
                amount: amount,
                fee: resolvedFee,
                blockHeight: transactionForInfo.transactionWithBlock.blockHeight,
                timestamp: transactionTimestamp,
                status: transaction.status
        )
    }

}
