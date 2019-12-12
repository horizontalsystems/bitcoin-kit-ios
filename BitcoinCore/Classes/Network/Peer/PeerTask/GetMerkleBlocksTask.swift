import Foundation

class GetMerkleBlocksTask: PeerTask {
    struct TooSlowPeer: Error {
        let minMerkleBlocks: Int
        let minTransactionsCount: Int
        let minTransactionsSize: Int
        let merkleBlocks: Int
        let transactionsCount: Int
        let transactionsSize: Int
    }

    private var waitingStartTime: Double = 0
    private var totalWaitingTime: Double = 0
    private var warningsCount = 0
    private var firstResponseReceived = false

    private var minMerkleBlocksCount: Double
    private var minTransactionsCount: Double
    private var minTransactionsSize: Double
    private var merkleBlocksCount = 0
    private var transactionsCount = 0
    private var transactionsSize = 0

    private let allowedIdleTime = 60.0
    private var blockHashes: [BlockHash]
    private var pendingMerkleBlocks = [MerkleBlock]()
    private var merkleBlockValidator: IMerkleBlockValidator
    private weak var merkleBlockHandler: IMerkleBlockHandler?

    init(blockHashes: [BlockHash], merkleBlockValidator: IMerkleBlockValidator, merkleBlockHandler: IMerkleBlockHandler,
         minMerkleBlocksCount: Double, minTransactionsCount: Double, minTransactionsSize: Double,
         dateGenerator: @escaping () -> Date = Date.init) {
        self.blockHashes = blockHashes
        self.merkleBlockValidator = merkleBlockValidator
        self.merkleBlockHandler = merkleBlockHandler
        self.minMerkleBlocksCount = minMerkleBlocksCount
        self.minTransactionsCount = minTransactionsCount
        self.minTransactionsSize = minTransactionsSize

        super.init(dateGenerator: dateGenerator)
    }

    override var state: String {
        "minMerkleBlocksCount: \(minMerkleBlocksCount); minTransactionsCount: \(minTransactionsCount); minTransactionsSize: \(minTransactionsSize)"
    }

    override func start() {
        let items = blockHashes.map { blockHash in
            InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: blockHash.headerHash)
        }

        requester?.send(message: GetDataMessage(inventoryItems: items))
        resumeWaiting()

        super.start()
    }

    override func handle(message: IMessage) throws -> Bool {
        pauseWaiting()
        var handled = false

        switch message {
        case let merkleBlockMessage as MerkleBlockMessage:
            let merkleBlock = try merkleBlockValidator.merkleBlock(from: merkleBlockMessage)
            merkleBlocksCount += 1
            transactionsCount += Int(merkleBlockMessage.totalTransactions)
            handled = handle(merkleBlock: merkleBlock)

        case let transactionMessage as TransactionMessage:
            transactionsSize += transactionMessage.size
            handled = handle(transaction: transactionMessage.transaction)

        default: ()
        }

        resumeWaiting()
        return handled
    }

    override func checkTimeout() {
        guard !blockHashes.isEmpty else {
            delegate?.handle(completedTask: self)
            return
        }

        pauseWaiting()
        guard totalWaitingTime >= 1 else {
            resumeWaiting()
            return
        }


        let minMerkleBlocksCount = Int((self.minMerkleBlocksCount * totalWaitingTime).rounded())
        let minTransactionsCount = Int((self.minTransactionsCount * totalWaitingTime).rounded())
        let minTransactionsSize = Int((self.minTransactionsSize * totalWaitingTime).rounded())

        if merkleBlocksCount < minMerkleBlocksCount && transactionsCount < minTransactionsCount && transactionsSize < minTransactionsSize {
            warningsCount += 1
            if warningsCount >= 10 {
                delegate?.handle(failedTask: self, error: TooSlowPeer(
                        minMerkleBlocks: minMerkleBlocksCount, minTransactionsCount: minTransactionsCount, minTransactionsSize: minTransactionsSize,
                        merkleBlocks: merkleBlocksCount, transactionsCount: transactionsCount, transactionsSize: transactionsSize
                ))
                return
            }
        }

        totalWaitingTime = 0
        merkleBlocksCount = 0
        transactionsCount = 0
        transactionsSize = 0
        resumeWaiting()
    }

    private func pauseWaiting() {
        let timePassed = dateGenerator().timeIntervalSince1970 - waitingStartTime

        if firstResponseReceived {
            totalWaitingTime += timePassed
        } else {
            firstResponseReceived = true
            totalWaitingTime += timePassed / 2
        }
    }

    private func resumeWaiting() {
        waitingStartTime = dateGenerator().timeIntervalSince1970
    }

    private func handle(merkleBlock: MerkleBlock) -> Bool {
        guard let blockHash = blockHashes.first(where: { blockHash in blockHash.headerHash == merkleBlock.headerHash }) else {
            return false
        }
        resetTimer()

        merkleBlock.height = blockHash.height > 0 ? blockHash.height : nil

        if merkleBlock.complete {
            handle(completeMerkleBlock: merkleBlock)
        } else {
            pendingMerkleBlocks.append(merkleBlock)
        }

        return true
    }

    private func handle(transaction: FullTransaction) -> Bool {
        if let index = pendingMerkleBlocks.firstIndex(where: { $0.transactionHashes.contains(transaction.header.dataHash) }) {
            resetTimer()

            let block = pendingMerkleBlocks[index]
            block.transactions.append(transaction)

            if block.complete {
                pendingMerkleBlocks.remove(at: index)
                handle(completeMerkleBlock: block)
            }

            return true
        }

        return false
    }

    private func handle(completeMerkleBlock merkleBlock: MerkleBlock) {
        if let index = blockHashes.firstIndex(where: { $0.headerHash == merkleBlock.headerHash }) {
            blockHashes.remove(at: index)
        }

        do {
            try merkleBlockHandler?.handle(merkleBlock: merkleBlock)
        } catch {
            delegate?.handle(failedTask: self, error: error)
        }

        if blockHashes.isEmpty {
            delegate?.handle(completedTask: self)
        }
    }

    func equalTo(_ task: GetMerkleBlocksTask?) -> Bool {
        guard let task = task else {
            return false
        }

        return blockHashes == task.blockHashes
    }

}
