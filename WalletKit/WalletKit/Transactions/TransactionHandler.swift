import Foundation

class TransactionHandler {

    enum HandleError: Error {
        case invalidBlockHeader
    }

    private let realmFactory: RealmFactory
    private let processor: TransactionProcessor
    private let progressSyncer: ProgressSyncer
    private let validateBlockFactory: ValidatedBlockFactory

    init(realmFactory: RealmFactory, processor: TransactionProcessor, progressSyncer: ProgressSyncer, validateBlockFactory: ValidatedBlockFactory) {
        self.realmFactory = realmFactory
        self.processor = processor
        self.progressSyncer = progressSyncer
        self.validateBlockFactory = validateBlockFactory
    }

    func handle(blockTransactions transactions: [Transaction], blockHeader: BlockHeader) throws {
        let realm = realmFactory.realm

        let reversedHashHex = Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: blockHeader)).reversedHex

        var hasNewTransactions = false
        var hasNewSyncedBlocks = false

        if let existingBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", reversedHashHex).last {
            if existingBlock.status == .synced {
                return
            }

            try realm.write {
                if existingBlock.header == nil {
                    existingBlock.header = blockHeader
                }

                for transaction in transactions {
                    if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                        existingTransaction.block = existingBlock
                        existingTransaction.status = .relayed
                    } else {
                        realm.add(transaction)
                        transaction.block = existingBlock
                        hasNewTransactions = true
                    }
                }

                existingBlock.status = .synced
                hasNewSyncedBlocks = true
            }
        } else {
            let block = try validateBlockFactory.block(fromHeader: blockHeader)

            block.status = .synced

            try realm.write {
                realm.add(block)

                for transaction in transactions {
                    if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                        existingTransaction.block = block
                        existingTransaction.status = .relayed
                    } else {
                        realm.add(transaction)
                        transaction.block = block
                        hasNewTransactions = true
                    }
                }

                hasNewSyncedBlocks = true
            }
        }

        if hasNewTransactions {
            processor.enqueueRun()
        }

        if hasNewSyncedBlocks {
            progressSyncer.enqueueRun()
        }
    }

    func handle(memPoolTransactions transactions: [Transaction]) throws {
        guard !transactions.isEmpty else {
            return
        }

        let realm = realmFactory.realm

        var hasNewTransactions = false

        try realm.write {
            for transaction in transactions {
                if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                    existingTransaction.status = .relayed
                } else {
                    realm.add(transaction)
                    hasNewTransactions = true
                }
            }
        }

        if hasNewTransactions {
            processor.enqueueRun()
        }
    }

}
