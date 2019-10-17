class PluginManager {
    private let addressConverter: IAddressConverter
    private let scriptConverter: IScriptConverter
    private let storage: IStorage
    private let blockMedianTimeHelper: IBlockMedianTimeHelper
    private var plugins = [UInt8: IPlugin]()

    init(addressConverter: IAddressConverter, scriptConverter: IScriptConverter, storage: IStorage, blockMedianTimeHelper: IBlockMedianTimeHelper) {
        self.addressConverter = addressConverter
        self.scriptConverter = scriptConverter
        self.storage = storage
        self.blockMedianTimeHelper = blockMedianTimeHelper
    }

}

extension PluginManager: IPluginManager {

    func add(plugin: IPlugin) {
        plugins[plugin.id] = plugin
    }

    func processOutputs(mutableTransaction: MutableTransaction, pluginData: [UInt8: [String: Any]]) throws {
        for (_, plugin) in plugins {
            try plugin.processOutputs(mutableTransaction: mutableTransaction, pluginData: pluginData, addressConverter: addressConverter)
        }
    }

    func processInputs(mutableTransaction: MutableTransaction) throws {
        for inputToSign in mutableTransaction.inputsToSign {
            guard let pluginId = inputToSign.previousOutput.pluginId, let plugin = plugins[pluginId] else {
                continue
            }

            inputToSign.input.sequence = try plugin.inputSequence(output: inputToSign.previousOutput)
        }
    }

    func processTransactionWithNullData(transaction: FullTransaction, nullDataOutput: Output) throws {
        let script = try scriptConverter.decode(data: nullDataOutput.lockingScript)
        var iterator = script.chunks.makeIterator()

        // the first byte OP_RETURN
        _ = iterator.next()

        while let pluginId = iterator.next() {
            guard let plugin = plugins[pluginId.opCode] else {
                break
            }

            try plugin.processTransactionWithNullData(transaction: transaction, nullDataChunks: &iterator, storage: storage, addressConverter: addressConverter)
        }
    }

    func isSpendable(unspentOutput: UnspentOutput) -> Bool {
        guard let pluginId = unspentOutput.output.pluginId, let plugin = plugins[pluginId] else {
            return true
        }

        return (try? plugin.isSpendable(unspentOutput: unspentOutput, blockMedianTimeHelper: blockMedianTimeHelper)) ?? true
    }

    public func parsePluginData(from output: Output) -> [UInt8: [String: Any]]? {
        guard let pluginId = output.pluginId, let plugin = plugins[pluginId],
              let parsedData = try? plugin.parsePluginData(from: output) else {
            return nil
        }

        return [plugin.id: parsedData]
    }

}
