import UIExtensions

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

        var inputsInfo = [TransactionInputInfo]()
        var outputsInfo = [TransactionOutputInfo]()
        let transaction = transactionForInfo.transactionWithBlock.transaction
        let transactionTimestamp = transaction.timestamp

        for inputWithPreviousOutput in transactionForInfo.inputsWithPreviousOutputs {
            var mine = false
            var value: Int? = nil

            if let previousOutput = inputWithPreviousOutput.previousOutput {
                value = previousOutput.value

                if previousOutput.publicKeyPath != nil {
                    mine = true
                }
            }

            inputsInfo.append(TransactionInputInfo(mine: mine, address: inputWithPreviousOutput.input.address, value: value))
        }

        for output in transactionForInfo.outputs {
            let outputInfo = TransactionOutputInfo(mine: output.publicKeyPath != nil, changeOutput: output.changeOutput, value: output.value, address: output.address)

            if let pluginId = output.pluginId, let pluginDataString = output.pluginData {
                outputInfo.pluginId = pluginId
                outputInfo.pluginDataString = pluginDataString
                outputInfo.pluginData = pluginManager.parsePluginData(fromPlugin: pluginId, pluginDataString: pluginDataString, transactionTimestamp: transactionTimestamp)
            }

            outputsInfo.append(outputInfo)
        }

        return T(
                uid: transaction.uid,
                transactionHash: transaction.dataHash.reversedHex,
                transactionIndex: transaction.order,
                inputs: inputsInfo,
                outputs: outputsInfo,
                amount: transactionForInfo.metaData.amount,
                type: transactionForInfo.metaData.type,
                fee: transactionForInfo.metaData.fee,
                blockHeight: transactionForInfo.transactionWithBlock.blockHeight,
                timestamp: transactionTimestamp,
                status: transaction.status,
                conflictingHash: transaction.conflictingTxHash?.reversedHex
        )
    }

    private func transactionInfo<T: TransactionInfo>(fromInvalidTransaction transactionForInfo: FullTransactionForInfo) -> T? {
        guard let invalidTransaction = transactionForInfo.transactionWithBlock.transaction as? InvalidTransaction else {
            return nil
        }

        guard let transactionInfo: T = try? JSONDecoder.init().decode(T.self, from: invalidTransaction.transactionInfoJson) else {
            return nil
        }

        for addressInfo in transactionInfo.outputs {
            if let pluginId = addressInfo.pluginId, let pluginDataString = addressInfo.pluginDataString {
                addressInfo.pluginData = pluginManager.parsePluginData(fromPlugin: pluginId, pluginDataString: pluginDataString, transactionTimestamp: invalidTransaction.timestamp)
            }
        }

        return transactionInfo
    }

}
