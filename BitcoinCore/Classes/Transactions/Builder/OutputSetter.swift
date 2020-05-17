class OutputSetter {
    private let outputSorterFactory: ITransactionDataSorterFactory
    private let factory: IFactory

    init(outputSorterFactory: ITransactionDataSorterFactory, factory: IFactory) {
        self.outputSorterFactory = outputSorterFactory
        self.factory = factory
    }

}

extension OutputSetter: IOutputSetter {

    func setOutputs(to transaction: MutableTransaction, sortType: TransactionDataSortType) {
        var outputs = [Output]()

        if let address = transaction.recipientAddress {
            outputs.append(factory.output(withIndex: 0, address: address, value: transaction.recipientValue, publicKey: nil))
        }

        if let address = transaction.changeAddress {
            outputs.append(factory.output(withIndex: 0, address: address, value: transaction.changeValue, publicKey: nil))
        }

        if !transaction.pluginData.isEmpty {
            var data = Data([OpCode.op_return])

            transaction.pluginData.forEach { key, value in
                data += Data([key]) + value
            }

            outputs.append(factory.nullDataOutput(data: data))
        }

        let sorted = outputSorterFactory.sorter(for: sortType).sort(outputs: outputs)
        sorted.enumerated().forEach { index, transactionOutput in
            transactionOutput.index = index
        }

        transaction.outputs = sorted
    }

}
