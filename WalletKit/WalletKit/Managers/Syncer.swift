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
    weak var transactionSender: TransactionSender?
    weak var blockSyncer: BlockSyncer?

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

    func peerGroupReady() {
        do {
            try headerSyncer?.sync()
        } catch {
            Logger.shared.log(self, "Header Syncer Error: \(error)")
        }

        // TODO: following callbacks need to be covered with tests
        blockSyncer?.enqueueRun()
        transactionSender?.enqueueRun()
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

    func shouldRequest(inventoryItem: InventoryItem) -> Bool {
        let realm = realmFactory.realm

        switch inventoryItem.objectType {
            case .transaction:
                return realm.objects(Transaction.self).filter("reversedHashHex = %@", inventoryItem.hash.reversedHex).isEmpty
            case .blockMessage:
                return realm.objects(Block.self).filter("reversedHeaderHashHex = %@", inventoryItem.hash.reversedHex).isEmpty
            case .filteredBlockMessage, .compactBlockMessage, .unknown, .error:
                return false
        }
    }

}
