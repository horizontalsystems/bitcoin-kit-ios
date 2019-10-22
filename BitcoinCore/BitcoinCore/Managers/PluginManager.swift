class PluginManager {
    enum PluginError: Error {
        case pluginNotFound
    }

    private let scriptConverter: IScriptConverter
    private var plugins = [UInt8: IPlugin]()

    private let logger: Logger?

    init(scriptConverter: IScriptConverter, logger: Logger? = nil) {
        self.scriptConverter = scriptConverter
        self.logger = logger
    }

}

extension PluginManager: IPluginManager {

    func add(plugin: IPlugin) {
        plugins[plugin.id] = plugin
    }

    func processOutputs(mutableTransaction: MutableTransaction, pluginData: [UInt8: [String: Any]]) throws {
        for (key, data) in pluginData {
            guard let plugin = plugins[key] else {
                throw PluginError.pluginNotFound
            }

            try plugin.processOutputs(mutableTransaction: mutableTransaction, pluginData: data)
        }
    }

    func processInputs(mutableTransaction: MutableTransaction) throws {
        for inputToSign in mutableTransaction.inputsToSign {
            guard let pluginId = inputToSign.previousOutput.pluginId else {
                continue
            }

            guard let plugin = plugins[pluginId] else {
                throw PluginError.pluginNotFound
            }

            inputToSign.input.sequence = try plugin.inputSequenceNumber(output: inputToSign.previousOutput)
        }
    }

    func processTransactionWithNullData(transaction: FullTransaction, nullDataOutput: Output) throws {
        do {
            let script = try scriptConverter.decode(data: nullDataOutput.lockingScript)
            var iterator = script.chunks.makeIterator()

            // the first byte OP_RETURN
            _ = iterator.next()

            while let pluginId = iterator.next() {
                guard let plugin = plugins[pluginId.opCode] else {
                    break
                }

                try plugin.processTransactionWithNullData(transaction: transaction, nullDataChunks: &iterator)
            }
        } catch {
            logger?.error(error)
        }
    }

    func isSpendable(unspentOutput: UnspentOutput) -> Bool {
        guard let pluginId = unspentOutput.output.pluginId else {
            return true
        }

        guard let plugin = plugins[pluginId] else {
            return false
        }

        return (try? plugin.isSpendable(unspentOutput: unspentOutput)) ?? true
    }

    public func parsePluginData(from output: Output, transactionTimestamp: Int) -> [UInt8: [String: Any]]? {
        guard let pluginId = output.pluginId, let plugin = plugins[pluginId],
              let parsedData = try? plugin.parsePluginData(from: output, transactionTimestamp: transactionTimestamp) else {
            return nil
        }

        return [plugin.id: parsedData]
    }

}

extension PluginManager: IRestoreKeyConverter {

    public func keysForApiRestore(publicKey: PublicKey) -> [String] {
        (try? plugins.flatMap({ try $0.value.keysForApiRestore(publicKey: publicKey) })) ?? []
    }

    public func bloomFilterElements(publicKey: PublicKey) -> [Data] {
        []
    }

}
