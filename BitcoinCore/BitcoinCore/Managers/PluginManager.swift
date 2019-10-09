class PluginManager {
    private let addressConverter: IAddressConverter
    private let storage: IStorage
    private var plugins = [IPlugin]()

    init(addressConverter: IAddressConverter, storage: IStorage) {
        self.addressConverter = addressConverter
        self.storage = storage
    }

}

extension PluginManager: IPluginManager {

    func processOutputs(mutableTransaction: MutableTransaction, extraData: [String: [String: Any]]) throws {
        for plugin in plugins {
            try plugin.processOutputs(mutableTransaction: mutableTransaction, extraData: extraData, addressConverter: addressConverter)
        }
    }

    func add(plugin: IPlugin) {
        plugins.append(plugin)
    }

}
