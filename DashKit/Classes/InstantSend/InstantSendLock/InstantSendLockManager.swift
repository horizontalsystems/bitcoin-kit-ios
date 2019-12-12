import BitcoinCore


class InstantSendLockManager: IInstantSendLockManager {

    private let instantSendLockValidator: IInstantSendLockValidator

    private(set) var relayedLocks = [Data: ISLockMessage]()

    init(instantSendLockValidator: IInstantSendLockValidator) {
        self.instantSendLockValidator = instantSendLockValidator
    }

    func add(relayed: ISLockMessage) {
        relayedLocks[relayed.txHash] = relayed
    }

    func takeRelayedLock(for txHash: Data) -> ISLockMessage? {
        if let lock = relayedLocks[txHash] {
            relayedLocks[txHash] = nil
            return lock
        }
        return nil
    }

    func validate(isLock: ISLockMessage) throws {
        try instantSendLockValidator.validate(isLock: isLock)
    }

}
