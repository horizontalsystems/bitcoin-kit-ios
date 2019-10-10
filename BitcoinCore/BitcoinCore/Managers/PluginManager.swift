class PluginManager {
    private let addressConverter: IAddressConverter
    private let scriptConverter: IScriptConverter
    private let storage: IStorage
    private var plugins = [UInt8: IPlugin]()

    init(addressConverter: IAddressConverter, scriptConverter: IScriptConverter, storage: IStorage) {
        self.addressConverter = addressConverter
        self.scriptConverter = scriptConverter
        self.storage = storage
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
}
