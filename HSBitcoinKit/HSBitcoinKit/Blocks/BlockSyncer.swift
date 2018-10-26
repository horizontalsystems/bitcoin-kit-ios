import HSCryptoKit
import RealmSwift

class BlockSyncer {

    private let realmFactory: IRealmFactory
    private let network: INetwork
    private let transactionProcessor: ITransactionProcessor
    private let blockchain: IBlockchain
    private let addressManager: IAddressManager
    private let bloomFilterManager: IBloomFilterManager

    private let hashCheckpointThreshold: Int
    private var needToReDownload = false

    init(realmFactory: IRealmFactory, network: INetwork,
         transactionProcessor: ITransactionProcessor, blockchain: IBlockchain, addressManager: IAddressManager, bloomFilterManager: IBloomFilterManager,
         hashCheckpointThreshold: Int = 100) {
        self.realmFactory = realmFactory
        self.network = network
        self.transactionProcessor = transactionProcessor
        self.blockchain = blockchain
        self.addressManager = addressManager
        self.bloomFilterManager = bloomFilterManager
        self.hashCheckpointThreshold = hashCheckpointThreshold

        let realm = realmFactory.realm
        if realm.objects(Block.self).count == 0, let checkpointBlockHeader = network.checkpointBlock.header {
            let checkpointBlock = Block(withHeader: checkpointBlockHeader, height: network.checkpointBlock.height)
            try? realm.write {
                realm.add(checkpointBlock)
            }
        }
    }

    // We need to clear block hashes when sync peer is disconnected
    private func clearBlockHashes() throws {
        let realm = realmFactory.realm

        try realm.write {
            realm.delete(realm.objects(BlockHash.self).filter("height = 0"))
        }
    }

    private func clearNotFullBlocks() throws {
        let realm = realmFactory.realm

        let blockReversedHashes = realm.objects(BlockHash.self)
                .filter("reversedHeaderHashHex != %@", network.checkpointBlock.reversedHeaderHashHex)
                .map { $0.reversedHeaderHashHex }

        let blocksToDelete = realm.objects(Block.self).filter(NSPredicate(format: "reversedHeaderHashHex IN %@", Array(blockReversedHashes)))

        try realm.write {
            for block in blocksToDelete {
                for transaction in block.transactions {
                    for output in transaction.outputs {
                        realm.delete(output)
                    }
                    for input in transaction.inputs {
                        realm.delete(input)
                    }
                    realm.delete(transaction)
                }
            }

            realm.delete(blocksToDelete)
        }
    }

}

extension BlockSyncer: IBlockSyncer {

    func prepareForDownload() {
        do {
            try addressManager.fillGap()
            bloomFilterManager.regenerateBloomFilter()
            needToReDownload = false

            try clearNotFullBlocks()
            try clearBlockHashes()

            blockchain.handleFork(realm: realmFactory.realm)
        } catch {
            print(error)
        }
    }

    func downloadStarted() {
    }

    func downloadIterationCompleted() {
        if needToReDownload {
            try? addressManager.fillGap()
            bloomFilterManager.regenerateBloomFilter()
            needToReDownload = false
        }
    }

    func downloadCompleted() {
        blockchain.handleFork(realm: realmFactory.realm)
    }

    func downloadFailed() {
        prepareForDownload()
    }

    func getBlockHashes() -> [Data] {
        let realm = realmFactory.realm
        let blockHashes = realm.objects(BlockHash.self).sorted(byKeyPath: "order")

        return blockHashes.prefix(500).map { blockHash in blockHash.headerHash }
    }

    func getBlockLocatorHashes() -> [Data] {
        let realm = realmFactory.realm
        var blockLocatorHashes = [Data]()

        if let lastBlockHash = realm.objects(BlockHash.self).filter("height = 0").sorted(byKeyPath: "order").last {
            blockLocatorHashes.append(lastBlockHash.headerHash)
        }

        if blockLocatorHashes.isEmpty {
            realm.objects(Block.self).sorted(byKeyPath: "height", ascending: false).prefix(10).forEach { block in
                blockLocatorHashes.append(block.headerHash)
            }
        }

        blockLocatorHashes.append(network.checkpointBlock.headerHash)

        return blockLocatorHashes
    }

    func add(blockHashes: [Data]) {
        let realm = realmFactory.realm
        var lastOrder = 0

        if let lastHash = realm.objects(BlockHash.self).sorted(byKeyPath: "order").last {
            lastOrder = lastHash.order
        }

        var hashes = [BlockHash]()
        for hash in blockHashes {
            lastOrder = lastOrder + 1
            hashes.append(BlockHash(withHeaderHash: hash, height: 0, order: lastOrder))
        }

        try? realm.write {
            realm.add(hashes)
        }
    }

    func handle(merkleBlock: MerkleBlock) throws {
        let realm = realmFactory.realm

        try realm.write {
            var block: Block!
            do {
                block = try blockchain.connect(merkleBlock: merkleBlock, realm: realm)
            } catch let error as BlockValidatorError {
                if error != BlockValidatorError.noPreviousBlock {
                    throw error
                }

                let height = realm.objects(BlockHash.self).filter("headerHash = %@", merkleBlock.headerHash).first?.height ?? 0
                if height > 0 {
                    block = blockchain.forceAdd(merkleBlock: merkleBlock, height: height, realm: realm)
                } else {
                    throw error
                }
            }

            do {
                try transactionProcessor.process(transactions: merkleBlock.transactions, inBlock: block, checkBloomFilter: !self.needToReDownload, realm: realm)
            } catch _ as BloomFilterManager.BloomFilterExpired {
                self.needToReDownload = true
            }

            if !self.needToReDownload, let blockHash = realm.objects(BlockHash.self).filter("headerHash = %@", block.headerHash).first {
                realm.delete(blockHash)
            }
        }
    }

    func shouldRequestBlock(withHash hash: Data) -> Bool {
        let realm = realmFactory.realm
        return realm.objects(Block.self).filter("headerHash == %@", hash).count == 0
    }

}
