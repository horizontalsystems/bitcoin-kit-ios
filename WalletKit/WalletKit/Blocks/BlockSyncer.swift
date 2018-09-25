import Foundation
import RealmSwift

class BlockSyncer {

    private let realmFactory: RealmFactory
    private let validateBlockFactory: ValidatedBlockFactory
    private let processor: TransactionProcessor
    private let progressSyncer: ProgressSyncer
    private let queue: DispatchQueue

    init(realmFactory: RealmFactory, validateBlockFactory: ValidatedBlockFactory, processor: TransactionProcessor, progressSyncer: ProgressSyncer, queue: DispatchQueue = DispatchQueue(label: "BlockSyncer", qos: .userInitiated)) {
        self.realmFactory = realmFactory
        self.validateBlockFactory = validateBlockFactory
        self.processor = processor
        self.progressSyncer = progressSyncer
        self.queue = queue
    }

    func _handle(merkleBlocks: [MerkleBlock]) throws {
        let realm = realmFactory.realm

        var hasNewTransactions = false
        var hasNewSyncedBlocks = false

        try realm.write {
            for merkleBlock in merkleBlocks {
                let blockHeader = merkleBlock.header
                let transactions = merkleBlock.transactions

                let reversedHashHex = Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: blockHeader)).reversedHex

                if let existingBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", reversedHashHex).last {
                    if existingBlock.synced {
                        return
                    }

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

                    existingBlock.synced = true
                    hasNewSyncedBlocks = true
                } else {
                    let block = try validateBlockFactory.block(fromHeader: blockHeader)

                    block.synced = true

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
        }

        if hasNewTransactions {
            processor.enqueueRun()
        }

        if hasNewSyncedBlocks {
            progressSyncer.enqueueRun()
        }
    }

}

extension BlockSyncer: IBlockSyncer {

    func getHashes(afterHash hash: Data?, limit: Int) -> [Data] {
        let realm = realmFactory.realm
        realm.refresh()

        let pendingBlocks: Results<Block>

        if let hash = hash, let block = realm.objects(Block.self).filter("headerHash = %@", hash).first {
            pendingBlocks = realm.objects(Block.self).filter("synced = %@ AND height > %@", false, block.height).sorted(byKeyPath: "height")
        } else {
            pendingBlocks = realm.objects(Block.self).filter("synced = %@", false).sorted(byKeyPath: "height")
        }

        let count = min(pendingBlocks.count, limit)
        return pendingBlocks.prefix(count).map { $0.headerHash }
    }

    func handle(merkleBlocks: [MerkleBlock]) {
        queue.async {
            do {
                try self._handle(merkleBlocks: merkleBlocks)
            } catch {
                Logger.shared.log(self, "Handle Error: \(error)")
            }
        }
    }

    func shouldRequestBlock(hash: Data) -> Bool {
        let realm = realmFactory.realm
        return realm.objects(Block.self).filter("reversedHeaderHashHex = %@", hash.reversedHex).isEmpty
    }

}

protocol IBlockSyncer: class {

    func getHashes(afterHash hash: Data?, limit: Int) -> [Data]
    func handle(merkleBlocks: [MerkleBlock])
    func shouldRequestBlock(hash: Data) -> Bool

}
