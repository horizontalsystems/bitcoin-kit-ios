class LockTimeSetter {
    private let storage: IStorage
    private let pluginManager: IPluginManager

    init(storage: IStorage, pluginManager: IPluginManager) {
        self.storage = storage
        self.pluginManager = pluginManager
    }

    func setLockTime(to mutableTransaction: MutableTransaction) throws {
        let pluginsMaxLockTime = try pluginManager.transactionLockTime(transaction: mutableTransaction)
        mutableTransaction.transaction.lockTime = pluginsMaxLockTime ?? storage.lastBlock?.height ?? 0
    }

}
