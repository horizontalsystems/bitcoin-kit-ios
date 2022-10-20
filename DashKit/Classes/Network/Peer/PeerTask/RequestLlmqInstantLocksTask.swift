import BitcoinCore

class RequestLlmqInstantLocksTask: PeerTask {

    var hashes = [Data]()
    var llmqInstantLocks = [ISLockMessage]()

    init(hashes: [Data], dateGenerator: @escaping () -> Date = Date.init) {
        self.hashes = hashes

        super.init(dateGenerator: dateGenerator)
    }

    override func start() {
        let items = hashes.map { hash in InventoryItem(type: DashInventoryType.msgIsLock.rawValue, hash: hash) }
        requester?.send(message: GetDataMessage(inventoryItems: items))

        super.start()
    }

    override func handle(message: IMessage) -> Bool {
        if let lockMessage = message as? ISLockMessage {
            return handleISLockRequest(isLock: lockMessage)
        }
        return false
    }

    private func handleISLockRequest(isLock: ISLockMessage) -> Bool {
        guard let index = hashes.firstIndex(of: isLock.hash) else {
            return false
        }

        hashes.remove(at: index)
        llmqInstantLocks.append(isLock)
        if hashes.isEmpty {
            delegate?.handle(completedTask: self)
        }

        return true
    }

}
