public protocol IBaseTransactionInfoConverter {
    func transactionInfo<T: TransactionInfo>(fromTransaction transactionForInfo: FullTransactionForInfo) -> T
}

public class BaseTransactionInfoConverter: IBaseTransactionInfoConverter {

    public init() {}

    public func transactionInfo<T: TransactionInfo>(fromTransaction transactionForInfo: FullTransactionForInfo) -> T {
        var totalMineInput: Int = 0
        var totalMineOutput: Int = 0
        var fromAddresses = [TransactionAddressInfo]()
        var toAddresses = [TransactionAddressInfo]()
        var hasOnlyMyInputs = true

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
                toAddresses.append(TransactionAddressInfo(address: address, mine: mine))
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
                transactionHash: transactionForInfo.transactionWithBlock.transaction.dataHash.reversedHex,
                transactionIndex: transactionForInfo.transactionWithBlock.transaction.order,
                from: fromAddresses,
                to: toAddresses,
                amount: amount,
                fee: resolvedFee,
                blockHeight: transactionForInfo.transactionWithBlock.blockHeight,
                timestamp: transactionForInfo.transactionWithBlock.transaction.timestamp
        )
    }

}
