class BlockSyncer {
    private let storage: IStorage

    private let listener: ISyncStateListener
    private let checkpointBlock: Block
    private let factory: IFactory
    private let transactionProcessor: ITransactionProcessor
    private let blockchain: IBlockchain
    private let publicKeyManager: IPublicKeyManager

    private let hashCheckpointThreshold: Int
    private var state: BlockSyncerState

    private let logger: Logger?

    init(storage: IStorage, checkpointBlock: Block, factory: IFactory, listener: ISyncStateListener, transactionProcessor: ITransactionProcessor,
         blockchain: IBlockchain, publicKeyManager: IPublicKeyManager, hashCheckpointThreshold: Int, logger: Logger?, state: BlockSyncerState
    ) {
        self.storage = storage
        self.checkpointBlock = checkpointBlock
        self.factory = factory
        self.transactionProcessor = transactionProcessor
        self.blockchain = blockchain
        self.publicKeyManager = publicKeyManager
        self.hashCheckpointThreshold = hashCheckpointThreshold
        self.listener = listener
        self.logger = logger
        self.state = state
    }

    var localDownloadedBestBlockHeight: Int32 {
        let height = storage.lastBlock?.height
        return Int32(height ?? 0)
    }

    var localKnownBestBlockHeight: Int32 {
        let blockchainHashes = storage.blockchainBlockHashes
        let existingHashesCount = storage.blocksCount(headerHashes: blockchainHashes.map { $0.headerHash })
        return localDownloadedBestBlockHeight + Int32(blockchainHashes.count - existingHashesCount)
    }

    // We need to clear block hashes when sync peer is disconnected
    private func clearBlockHashes() {
        storage.deleteBlockchainBlockHashes()
    }

    private func clearPartialBlocks() throws {
        let blockReversedHashes = storage.blockHashHeaderHashes(except: checkpointBlock.headerHash)

        let blocksToDelete = storage.blocks(byHexes: blockReversedHashes)
        try blockchain.deleteBlocks(blocks: blocksToDelete)
    }

    private func handlePartialBlocks() throws {
        try publicKeyManager.fillGap()
        state.iteration(hasPartialBlocks: false)
    }

}

extension BlockSyncer: IBlockSyncer {

    func prepareForDownload() {
        do {
            try handlePartialBlocks()
            try clearPartialBlocks()
            clearBlockHashes()

            try blockchain.handleFork()
        } catch {
            logger?.error(error)
        }
    }

    func downloadStarted() {
    }

    func downloadIterationCompleted() {
        if state.iterationHasPartialBlocks {
            try? handlePartialBlocks()
        }
    }

    func downloadCompleted() {
        try? blockchain.handleFork()
    }

    func downloadFailed() {
        prepareForDownload()
    }

    func getBlockHashes() -> [BlockHash] {
        return storage.blockHashesSortedBySequenceAndHeight(limit: 500)
    }

    func getBlockLocatorHashes(peerLastBlockHeight: Int32) -> [Data] {
        var blockLocatorHashes = [Data]()

        if let lastBlockHash = storage.lastBlockchainBlockHash {
            blockLocatorHashes.append(lastBlockHash.headerHash)
        }

        if blockLocatorHashes.isEmpty {
            for block in storage.blocks(heightGreaterThan: checkpointBlock.height, sortedBy: Block.Columns.height, limit: 10) {
                blockLocatorHashes.append(block.headerHash)
            }
        }

        if let peerLastBlock = storage.block(byHeight: Int(peerLastBlockHeight)) {
            if !blockLocatorHashes.contains(peerLastBlock.headerHash) {
                blockLocatorHashes.append(peerLastBlock.headerHash)
            }
        } else {
            blockLocatorHashes.append(checkpointBlock.headerHash)
        }

        return blockLocatorHashes
    }

    func add(blockHashes: [Data]) {
        var lastOrder = storage.lastBlockHash?.sequence ?? 0
        let existingHashes = storage.blockHashHeaderHashes

        let blockHashes: [BlockHash] = blockHashes
                .filter {
                    !existingHashes.contains($0)
                }.map {
                    lastOrder += 1
                    return factory.blockHash(withHeaderHash: $0, height: 0, order: lastOrder)
                }

        storage.add(blockHashes: blockHashes)
    }

    func handle(merkleBlock: MerkleBlock, maxBlockHeight: Int32) throws {
        var block: Block!

        if let height = merkleBlock.height {
            block = try blockchain.forceAdd(merkleBlock: merkleBlock, height: height)
        } else {
            block = try blockchain.connect(merkleBlock: merkleBlock)
        }

        do {
            try transactionProcessor.processReceived(transactions: merkleBlock.transactions, inBlock: block, skipCheckBloomFilter: self.state.iterationHasPartialBlocks)
        } catch _ as BloomFilterManager.BloomFilterExpired {
            state.iteration(hasPartialBlocks: true)
        }

        if !state.iterationHasPartialBlocks {
            storage.deleteBlockHash(byHash: block.headerHash)
        }

        listener.currentBestBlockHeightUpdated(height: Int32(block.height), maxBlockHeight: maxBlockHeight)
    }

    func shouldRequestBlock(withHash hash: Data) -> Bool {
        return storage.block(byHash: hash) == nil
    }

}

extension BlockSyncer {

    public static func instance(storage: IStorage, checkpointBlock: Block, factory: IFactory, listener: ISyncStateListener,
                                transactionProcessor: ITransactionProcessor, blockchain: IBlockchain, publicKeyManager: IPublicKeyManager,
                                hashCheckpointThreshold: Int = 100, logger: Logger? = nil, state: BlockSyncerState = BlockSyncerState()) -> BlockSyncer {

        let syncer = BlockSyncer(storage: storage, checkpointBlock: checkpointBlock, factory: factory, listener: listener, transactionProcessor: transactionProcessor,
                blockchain: blockchain, publicKeyManager: publicKeyManager, hashCheckpointThreshold: hashCheckpointThreshold, logger: logger, state: state)

        listener.initialBestBlockHeightUpdated(height: syncer.localDownloadedBestBlockHeight)

        return syncer
    }

    public static func checkpointBlock(network: INetwork, syncMode: BitcoinCore.SyncMode, storage: IStorage) -> Block {
        let lastBlock = storage.lastBlock
        let checkpointBlock: Block

        if syncMode == .full {
            checkpointBlock = network.bip44CheckpointBlock
        } else if let block = lastBlock, block.height < network.lastCheckpointBlock.height {
            // When app is updated there may be case when the last block in DB is earlier than new checkpoint block.
            // In this case we set the very first checkpoint block for bip44,
            // since it surely will be earlier than the last block in DB
            checkpointBlock = network.bip44CheckpointBlock
        } else {
            checkpointBlock = network.lastCheckpointBlock
        }

        if lastBlock == nil {
            storage.save(block: checkpointBlock)
        }

        return checkpointBlock
    }

}
