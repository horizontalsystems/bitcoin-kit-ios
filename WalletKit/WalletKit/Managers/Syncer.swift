import Foundation
import RxSwift
import RealmSwift

class Syncer {

    enum SyncStatus {
        case syncing
        case synced
        case error
    }

    weak var headerSyncer: HeaderSyncer?
    weak var headerHandler: HeaderHandler?
    weak var transactionHandler: TransactionHandler?

    private let realmFactory: RealmFactory

    let syncSubject = BehaviorSubject<SyncStatus>(value: .synced)

    private var status: SyncStatus = .synced {
        didSet {
            syncSubject.onNext(status)
        }
    }

    init(realmFactory: RealmFactory) {
        self.realmFactory = realmFactory
    }

    private func initialSync() {
        status = .syncing
    }

}

extension Syncer: PeerGroupDelegate {

    func getHeadersHashes() -> [Data] {
        return headerSyncer?.getHeaders() ?? []
    }

    func getNonSyncedMerkleBlocksHashes(limit: Int) -> [Data] {
        let realm = realmFactory.realm

        let pendingBlocks = realm.objects(Block.self).filter("status = %@", Block.Status.pending.rawValue)

        guard !pendingBlocks.isEmpty else {
            return []
        }

        let count = min(limit, pendingBlocks.count)

        let blocks = Array(pendingBlocks.prefix(count))

        try? realm.write {
            for block in blocks {
                block.status = .syncing
            }
        }

        return blocks.map { $0.headerHash }
    }

    func peerGroupDidReceive(headers: [BlockHeader]) {
        if headers.isEmpty {
            return
        }

        do {
            try headerHandler?.handle(headers: headers)
        } catch {
            Logger.shared.log(self, "Header Handler Error: \(error)")
        }
    }

    func peerGroupDidReceive(blockHeader: BlockHeader, withTransactions transactions: [Transaction]) {
        do {
            try transactionHandler?.handle(blockTransactions: transactions, blockHeader: blockHeader)
        } catch {
            Logger.shared.log(self, "Transaction Handler Error: \(error)")
        }
    }

    func peerGroupDidReceive(transaction: Transaction) {
        do {
            try transactionHandler?.handle(memPoolTransactions: [transaction])
        } catch {
            Logger.shared.log(self, "Transaction Handler Error: \(error)")
        }
    }

    func shouldRequestBlock(hash: Data) -> Bool {
        let realm = realmFactory.realm
        return realm.objects(Block.self).filter("reversedHeaderHashHex = %@", hash.reversedHex).isEmpty
    }

    func shouldRequestTransaction(hash: Data) -> Bool {
        let realm = realmFactory.realm
        return realm.objects(Transaction.self).filter("reversedHashHex = %@", hash.reversedHex).isEmpty
    }

}
