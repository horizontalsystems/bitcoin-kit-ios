import BitcoinCore
import HsToolKit

class InstantSendLockHandler: IInstantSendLockHandler {
    private let instantTransactionManager: IInstantTransactionManager
    private let instantLockManager: IInstantSendLockManager

    public weak var delegate: IInstantTransactionDelegate?
    private let logger: Logger?

    init(instantTransactionManager: IInstantTransactionManager, instantSendLockManager: IInstantSendLockManager, logger: Logger? = nil) {
        self.instantTransactionManager = instantTransactionManager
        self.instantLockManager = instantSendLockManager
        self.logger = logger
    }

    public func handle(transactionHash: Data) {
        // get relayed lock for inserted transaction and check it
        if let lock = instantLockManager.takeRelayedLock(for: transactionHash) {
            validateSendLock(isLock: lock)
        }
    }

    public func handle(isLock: ISLockMessage) {
        // check transaction already not in instant
        guard !instantTransactionManager.isTransactionInstant(txHash: isLock.txHash) else {
            return
        }
        // do nothing if tx doesn't exist
        guard instantTransactionManager.isTransactionExists(txHash: isLock.txHash) else {
            instantLockManager.add(relayed: isLock)
            return
        }
        // validation
        validateSendLock(isLock: isLock)
    }

    private func validateSendLock(isLock: ISLockMessage) {
        do {
            try instantLockManager.validate(isLock: isLock)

            instantTransactionManager.makeInstant(txHash: isLock.txHash)
            delegate?.onUpdateInstant(transactionHash: isLock.txHash)
        } catch {
            logger?.error(error)
        }
    }

}
