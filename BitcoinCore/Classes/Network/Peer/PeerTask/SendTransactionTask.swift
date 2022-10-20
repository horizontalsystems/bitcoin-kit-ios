import Foundation
import UIExtensions

class SendTransactionTask: PeerTask {

    var transaction: FullTransaction
    private let allowedIdleTime: TimeInterval

    init(transaction: FullTransaction, allowedIdleTime: TimeInterval = 30, dateGenerator: @escaping () -> Date = Date.init) {
        self.transaction = transaction
        self.allowedIdleTime = allowedIdleTime

        super.init(dateGenerator: dateGenerator)
    }

    override var state: String {
        "transaction: \(transaction.header.dataHash.reversedHex)"
    }

    override func start() {
        let message = InventoryMessage(inventoryItems: [
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: transaction.header.dataHash)
        ])

        requester?.send(message: message)

        super.start()
    }

    override func handle(message: IMessage) throws -> Bool {
        var handled = false

        if let getDataMessage = message as? GetDataMessage {
            // We assume that this is the only task waiting for all inventories in this message
            // Otherwise, it means that we also must feed other tasks with this message
            // and we must have a smarter message handling mechanism
            for item in getDataMessage.inventoryItems {
                if handle(getDataInventoryItem: item) {
                    handled = true
                }
            }
        }

        return handled
    }

    override func checkTimeout() {
        if let lastActiveTime = lastActiveTime {
            if dateGenerator().timeIntervalSince1970 - lastActiveTime > allowedIdleTime {
                delegate?.handle(completedTask: self)
            }
        }
    }

    private func handle(getDataInventoryItem item: InventoryItem) -> Bool {
        guard item.objectType == .transaction && item.hash == transaction.header.dataHash else {
            return false
        }

        requester?.send(message: TransactionMessage(transaction: transaction, size: 0))
        delegate?.handle(completedTask: self)

        return true
    }

    func equalTo(_ task: SendTransactionTask?) -> Bool {
        guard let task = task else {
            return false
        }

        return transaction.header.dataHash == task.transaction.header.dataHash
    }

}
