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

    func processOutputs(mutableTransaction: MutableTransaction, pluginData: [String: [String: Any]]) throws {
        for (_, plugin) in plugins {
            try plugin.processOutputs(mutableTransaction: mutableTransaction, pluginData: pluginData, addressConverter: addressConverter)
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

    func isSpendable(output: Output) -> Bool {
        guard let pluginId = output.pluginId, let plugin = plugins[pluginId] else {
            return true
        }

        guard let blockMedianTime = blockMedianTimeHelper.medianTimePast else {
            return false
        }

        return (try? plugin.isSpendable(output: output, medianTime: blockMedianTime)) ?? true
    }

    func transactionLockTime(transaction: MutableTransaction) throws -> Int? {
        let lockTimes: [Int] = try transaction.inputsToSign.compactMap { inputToSign in
            try inputToSign.previousOutput.pluginId.flatMap { pluginId in
                try plugins[pluginId]?.transactionLockTime(output: inputToSign.previousOutput)
            }
        }

        return lockTimes.max()
    }

}
