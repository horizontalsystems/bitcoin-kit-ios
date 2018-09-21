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

    func getNonSyncedMerkleBlocksHashes() -> [Data] {
        let realm = realmFactory.realm
        let pendingBlocks = realm.objects(Block.self).filter("status = %@", Block.Status.pending.rawValue)
        return pendingBlocks.map { $0.headerHash }
    }

    func getNonSentTransactions() -> [Transaction] {
        let realm = realmFactory.realm
        let nonSentTransactions = realm.objects(Transaction.self).filter("status = %@", TransactionStatus.new.rawValue)
        return Array(nonSentTransactions)
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

    func peerGroupDidReceive(merkleBlocks: [MerkleBlock]) {
        do {
            try transactionHandler?.handle(merkleBlocks: merkleBlocks)
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
