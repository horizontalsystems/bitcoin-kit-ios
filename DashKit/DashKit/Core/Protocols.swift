import BigInt
import BitcoinCore

// BitcoinCore Compatibility

protocol IDashDifficultyEncoder {
    func decodeCompact(bits: Int) -> BigInt
    func encodeCompact(from bigInt: BigInt) -> Int
}

protocol IDashHasher {
    func hash(data: Data) -> Data
}

protocol IDashBlockValidatorHelper {
    func previous(for block: Block, count: Int) -> Block?
}

// ###############################

protocol IPeerTaskFactory {
    func createRequestMasternodeListDiffTask(baseBlockHash: Data, blockHash: Data) -> PeerTask
}

protocol IMasternodeListManager {
    var baseBlockHash: Data { get }
    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws
}

protocol IMasternodeListSyncer {
    func sync(blockHash: Data)
}

protocol IDashStorage {
    var masternodes: [Masternode] { get set }
    var masternodeListState: MasternodeListState? { get set }

    func instantTransactionInput(for inputTxHash: Data) -> InstantTransactionInput?
    func instantTransactionInputs(for txHash: Data) -> [InstantTransactionInput]
    func add(instantTransactionInput: InstantTransactionInput)

    func block(byHashHex: String) -> Block?
}

protocol IInstantSendFactory {
    func instantTransactionInput(txHash: Data, inputTxHash: Data, voteCount: Int, blockHeight: Int?) -> InstantTransactionInput
}

protocol IMasternodeSortedList {
    var masternodes: [Masternode] { get }

    func add(masternodes: [Masternode])
    func removeAll()
    func remove(masternodes: [Masternode])
    func remove(by proRegTxHashes: [Data])
}

protocol IMasternodeListMerkleRootCalculator {
    func calculateMerkleRoot(sortedMasternodes: [Masternode]) -> Data?
}

protocol IMasternodeCbTxHasher {
    func hash(coinbaseTransaction: CoinbaseTransaction) -> Data
}

protocol IMasternodeSerializer {
    func serialize(masternode: Masternode) -> Data
}

protocol ICoinbaseTransactionSerializer {
    func serialize(coinbaseTransaction: CoinbaseTransaction) -> Data
}

protocol IMerkleRootCreator {
    func create(hashes: [Data]) -> Data?
}

protocol IInstantTransactionManager {
    func handle(transactions: [FullTransaction])
    func handle(lockVote: TransactionLockVoteMessage) throws
}

protocol IMasternodeParser {
    func parse(byteStream: ByteStream) -> Masternode
}

protocol ITransactionLockVoteValidator {
    func validate(quorumModifierHash: Data, masternodeProTxHash: Data) throws
}