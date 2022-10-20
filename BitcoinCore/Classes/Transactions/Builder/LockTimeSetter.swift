class LockTimeSetter {
    private let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

}

extension LockTimeSetter: ILockTimeSetter {

    func setLockTime(to mutableTransaction: MutableTransaction) {
        mutableTransaction.transaction.lockTime = storage.lastBlock?.height ?? 0
    }

}
