class LockTimeSetter {
    private let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    func setLockTime(to mutableTransaction: MutableTransaction) {
        mutableTransaction.transaction.lockTime = storage.lastBlock?.height ?? 0
    }

}
