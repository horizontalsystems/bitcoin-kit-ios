public protocol IBaseTransactionInfoConverter {
    func transactionInfo<T: TransactionInfo>(fromTransaction transactionForInfo: FullTransactionForInfo) -> T
}

public class BaseTransactionInfoConverter: IBaseTransactionInfoConverter {
    private let pluginManager: IPluginManager

    public init(pluginManager: IPluginManager) {
        self.pluginManager = pluginManager
    }

    public func transactionInfo<T: TransactionInfo>(fromTransaction transactionForInfo: FullTransactionForInfo) -> T {
        if let invalidTransactionInfo: T = transactionInfo(fromInvalidTransaction: transactionForInfo) {
            return invalidTransactionInfo
        }

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
                fromAddresses.append(TransactionAddressInfo(address: address, mine: mine))
            }
        }

        for output in transactionForInfo.outputs {
            var mine = false

            if output.publicKeyPath != nil {
                totalMineOutput += output.value
                mine = true
            }

            if let address = output.address {
                let addressInfo = TransactionAddressInfo(address: address, mine: mine)

                if let pluginId = output.pluginId, let pluginDataString = output.pluginData {
                    addressInfo.pluginId = pluginId
                    addressInfo.pluginDataString = pluginDataString
                    addressInfo.pluginData = pluginManager.parsePluginData(fromPlugin: pluginId, pluginDataString: pluginDataString, transactionTimestamp: transactionTimestamp)
                }

                toAddresses.append(addressInfo)
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

    private func transactionInfo<T: TransactionInfo>(fromInvalidTransaction transactionForInfo: FullTransactionForInfo) -> T? {
        guard let invalidTransaction = transactionForInfo.transactionWithBlock.transaction as? InvalidTransaction else {
            return nil
        }

        guard let transactionInfo: T = try? JSONDecoder.init().decode(T.self, from: invalidTransaction.transactionInfoJson) else {
            return nil
        }

        for addressInfo in transactionInfo.to {
            if let pluginId = addressInfo.pluginId, let pluginDataString = addressInfo.pluginDataString {
                addressInfo.pluginData = pluginManager.parsePluginData(fromPlugin: pluginId, pluginDataString: pluginDataString, transactionTimestamp: invalidTransaction.timestamp)
            }
        }

        return transactionInfo
    }

}
