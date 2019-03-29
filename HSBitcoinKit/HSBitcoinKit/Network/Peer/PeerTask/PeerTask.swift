import Foundation

class PeerTask {
    class TimeoutError: Error {
    }

    internal let dateGenerator: () -> Date
    internal var lastActiveTime: Double? = nil

    weak var requester: IPeerTaskRequester?
    weak var delegate: IPeerTaskDelegate?

    init(dateGenerator: @escaping () -> Date = Date.init) {
        self.dateGenerator = dateGenerator
    }

    func start() {
    }

    func handle(blockHeaders: [BlockHeader]) -> Bool {
        return false
    }

    func handle(merkleBlock: MerkleBlock) -> Bool {
        return false
    }

    func handle(transaction: FullTransaction) -> Bool {
        return false
    }

    func handle(getDataInventoryItem item: InventoryItem) -> Bool {
        return false
    }

    func handle(items: [InventoryItem]) -> Bool {
        return false
    }

    func handle(message: IMessage) -> Bool {
        return false
    }

    func isRequestingInventory(hash: Data) -> Bool {
        return false
    }

    func checkTimeout() {
    }

    func resetTimer() {
        lastActiveTime = dateGenerator().timeIntervalSince1970
    }

}

extension PeerTask: Equatable {

    static func ==(lhs: PeerTask, rhs: PeerTask) -> Bool {
        switch lhs {
        case let t as GetBlockHashesTask: return t.equalTo(rhs as? GetBlockHashesTask)
        case let t as GetMerkleBlocksTask: return t.equalTo(rhs as? GetMerkleBlocksTask)
        case let t as SendTransactionTask: return t.equalTo(rhs as? SendTransactionTask)
        case let t as RequestTransactionsTask: return t.equalTo(rhs as? RequestTransactionsTask)
        default: return true
        }
    }

}
