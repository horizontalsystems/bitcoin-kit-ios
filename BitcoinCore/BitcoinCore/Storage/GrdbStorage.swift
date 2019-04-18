import RxSwift
import GRDB

public class GrdbStorage {
    var dbPool: DatabasePool
    private var dbsInTransaction = [Int: Database]()

    private let databaseName: String
    private var databaseURL: URL

    init(databaseFileName: String) {
        self.databaseName = databaseFileName

        databaseURL = try! FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("\(databaseName).sqlite")

        var configuration = Configuration()
//        configuration.trace = { print($0) }
        dbPool = try! DatabasePool(path: databaseURL.path, configuration: configuration)

        try? migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createFeeRates") { db in
            try db.create(table: FeeRate.databaseTableName) { t in
                t.column(FeeRate.Columns.primaryKey.name, .text).notNull()
                t.column(FeeRate.Columns.lowPriority.name, .text).notNull()
                t.column(FeeRate.Columns.mediumPriority.name, .text).notNull()
                t.column(FeeRate.Columns.highPriority.name, .text).notNull()
                t.column(FeeRate.Columns.date.name, .date).notNull()

                t.primaryKey([FeeRate.Columns.primaryKey.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createBlockchainStates") { db in
            try db.create(table: BlockchainState.databaseTableName) { t in
                t.column(BlockchainState.Columns.primaryKey.name, .text).notNull()
                t.column(BlockchainState.Columns.initialRestored.name, .boolean)

                t.primaryKey([BlockchainState.Columns.primaryKey.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createPeerAddresses") { db in
            try db.create(table: PeerAddress.databaseTableName) { t in
                t.column(PeerAddress.Columns.ip.name, .text).notNull()
                t.column(PeerAddress.Columns.score.name, .integer).notNull()

                t.primaryKey([PeerAddress.Columns.ip.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createBlockHashes") { db in
            try db.create(table: BlockHash.databaseTableName) { t in
                t.column(BlockHash.Columns.headerHashReversedHex.name, .text).notNull()
                t.column(BlockHash.Columns.headerHash.name, .blob).notNull()
                t.column(BlockHash.Columns.height.name, .integer).notNull()
                t.column(BlockHash.Columns.sequence.name, .integer).notNull()

                t.primaryKey([BlockHash.Columns.headerHashReversedHex.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createSentTransactions") { db in
            try db.create(table: SentTransaction.databaseTableName) { t in
                t.column(SentTransaction.Columns.hashReversedHex.name, .text).notNull()
                t.column(SentTransaction.Columns.firstSendTime.name, .double).notNull()
                t.column(SentTransaction.Columns.lastSendTime.name, .double).notNull()
                t.column(SentTransaction.Columns.retriesCount.name, .integer).notNull()

                t.primaryKey([SentTransaction.Columns.hashReversedHex.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createPublicKeys") { db in
            try db.create(table: PublicKey.databaseTableName) { t in
                t.column(PublicKey.Columns.path.name, .text).notNull()
                t.column(PublicKey.Columns.account.name, .integer).notNull()
                t.column(PublicKey.Columns.index.name, .integer).notNull()
                t.column(PublicKey.Columns.external.name, .boolean).notNull()
                t.column(PublicKey.Columns.raw.name, .blob).notNull()
                t.column(PublicKey.Columns.keyHash.name, .blob).notNull()
                t.column(PublicKey.Columns.scriptHashForP2WPKH.name, .blob).notNull()
                t.column(PublicKey.Columns.keyHashHex.name, .text).notNull()

                t.primaryKey([PublicKey.Columns.path.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createBlocks") { db in
            try db.create(table: Block.databaseTableName) { t in
                t.column(Block.Columns.version.name, .integer).notNull()
                t.column(Block.Columns.previousBlockHashReversedHex.name, .text).notNull()
                t.column(Block.Columns.merkleRoot.name, .blob).notNull()
                t.column(Block.Columns.timestamp.name, .integer).notNull()
                t.column(Block.Columns.bits.name, .integer).notNull()
                t.column(Block.Columns.nonce.name, .integer).notNull()
                t.column(Block.Columns.headerHashReversedHex.name, .text).notNull()
                t.column(Block.Columns.headerHash.name, .blob).notNull()
                t.column(Block.Columns.height.name, .integer).notNull()
                t.column(Block.Columns.stale.name, .boolean)

                t.primaryKey([Block.Columns.headerHashReversedHex.name], onConflict: .replace)
            }
            try db.create(index: "by\(Block.Columns.height.name)", on: Block.databaseTableName, columns: [Block.Columns.height.name], unique: true)
        }

        migrator.registerMigration("createTransactions") { db in
            try db.create(table: Transaction.databaseTableName) { t in
                t.column(Transaction.Columns.dataHashReversedHex.name, .text).notNull()
                t.column(Transaction.Columns.dataHash.name, .blob).notNull()
                t.column(Transaction.Columns.version.name, .integer).notNull()
                t.column(Transaction.Columns.lockTime.name, .integer).notNull()
                t.column(Transaction.Columns.timestamp.name, .integer).notNull()
                t.column(Transaction.Columns.order.name, .integer).notNull()
                t.column(Transaction.Columns.blockHashReversedHex.name, .text)
                t.column(Transaction.Columns.isMine.name, .boolean)
                t.column(Transaction.Columns.isOutgoing.name, .boolean)
                t.column(Transaction.Columns.status.name, .integer)
                t.column(Transaction.Columns.segWit.name, .boolean)

                t.primaryKey([Transaction.Columns.dataHashReversedHex.name], onConflict: .replace)
                t.foreignKey([Transaction.Columns.blockHashReversedHex.name], references: Block.databaseTableName, columns: [Block.Columns.headerHashReversedHex.name], onDelete: .cascade, onUpdate: .cascade)
            }
        }

        migrator.registerMigration("createInputs") { db in
            try db.create(table: Input.databaseTableName) { t in
                t.column(Input.Columns.previousOutputTxReversedHex.name, .text).notNull()
                t.column(Input.Columns.previousOutputIndex.name, .integer).notNull()
                t.column(Input.Columns.signatureScript.name, .blob).notNull()
                t.column(Input.Columns.sequence.name, .integer).notNull()
                t.column(Input.Columns.transactionHashReversedHex.name, .text).notNull()
                t.column(Input.Columns.keyHash.name, .blob)
                t.column(Input.Columns.address.name, .text)
                t.column(Input.Columns.witnessData.name, .blob)

                t.primaryKey([Input.Columns.previousOutputTxReversedHex.name, Input.Columns.previousOutputIndex.name], onConflict: .replace)
                t.foreignKey([Input.Columns.transactionHashReversedHex.name], references: Transaction.databaseTableName, columns: [Transaction.Columns.dataHashReversedHex.name], onDelete: .cascade, onUpdate: .cascade, deferred: true)
            }
        }

        migrator.registerMigration("createOutputs") { db in
            try db.create(table: Output.databaseTableName) { t in
                t.column(Output.Columns.value.name, .integer).notNull()
                t.column(Output.Columns.lockingScript.name, .blob).notNull()
                t.column(Output.Columns.index.name, .integer).notNull()
                t.column(Output.Columns.transactionHashReversedHex.name, .text).notNull()
                t.column(Output.Columns.publicKeyPath.name, .text)
                t.column(Output.Columns.scriptType.name, .integer)
                t.column(Output.Columns.keyHash.name, .blob)
                t.column(Output.Columns.address.name, .text)

                t.primaryKey([Output.Columns.transactionHashReversedHex.name, Output.Columns.index.name], onConflict: .replace)
                t.foreignKey([Output.Columns.transactionHashReversedHex.name], references: Transaction.databaseTableName, columns: [Transaction.Columns.dataHashReversedHex.name], onDelete: .cascade, onUpdate: .cascade, deferred: true)
                t.foreignKey([Output.Columns.publicKeyPath.name], references: PublicKey.databaseTableName, columns: [PublicKey.Columns.path.name], onDelete: .setNull, onUpdate: .setNull)
            }
        }

        migrator.registerMigration("changeTypesFeeRates") { db in
            try db.drop(table: FeeRate.databaseTableName)
            try db.create(table: FeeRate.databaseTableName) { t in
                t.column(FeeRate.Columns.primaryKey.name, .text).notNull()
                t.column(FeeRate.Columns.lowPriority.name, .integer).notNull()
                t.column(FeeRate.Columns.mediumPriority.name, .integer).notNull()
                t.column(FeeRate.Columns.highPriority.name, .integer).notNull()
                t.column(FeeRate.Columns.date.name, .date).notNull()

                t.primaryKey([FeeRate.Columns.primaryKey.name], onConflict: .replace)
            }
        }

        return migrator
    }

    func clearGrdb() throws {
        _ = try! dbPool.write { db in
            try FeeRate.deleteAll(db)
            try BlockchainState.deleteAll(db)
            try PeerAddress.deleteAll(db)
            try BlockHash.deleteAll(db)
            try SentTransaction.deleteAll(db)
            try Input.deleteAll(db)
            try Output.deleteAll(db)
            try Transaction.deleteAll(db)
            try PublicKey.deleteAll(db)
            try Block.deleteAll(db)
        }
    }

}

extension GrdbStorage: IStorage {
    // FeeRate

    var feeRate: FeeRate? {
        return try! dbPool.read { db in
            try FeeRate.fetchOne(db)
        }
    }

    func set(feeRate: FeeRate) {
        _ = try! dbPool.write { db in
            try feeRate.insert(db)
        }
    }

    // BlockchainState

    var initialRestored: Bool? {
        return try! dbPool.read { db in
            try BlockchainState.fetchOne(db)?.initialRestored
        }
    }

    func set(initialRestored: Bool) {
        _ = try! dbPool.write { db in
            let state = try BlockchainState.fetchOne(db) ?? BlockchainState()
            state.initialRestored = initialRestored
            try state.insert(db)
        }
    }

    // PeerAddress

    func existingPeerAddresses(fromIps ips: [String]) -> [PeerAddress] {
        return try! dbPool.read { db in
            try PeerAddress
                    .filter(ips.contains(PeerAddress.Columns.ip))
                    .fetchAll(db)
        }
    }

    func leastScorePeerAddress(excludingIps: [String]) -> PeerAddress? {
        return try! dbPool.read { db in
            try PeerAddress
                    .filter(!excludingIps.contains(PeerAddress.Columns.ip))
                    .order(PeerAddress.Columns.score.asc)
                    .fetchOne(db)
        }
    }

    func save(peerAddresses: [PeerAddress]) {
        _ = try! dbPool.write { db in
            for peerAddress in peerAddresses {
                try peerAddress.insert(db)
            }
        }
    }

    func increasePeerAddressScore(ip: String) {
        _ = try! dbPool.write { db in
            if let peerAddress = try PeerAddress.filter(PeerAddress.Columns.ip == ip).fetchOne(db) {
                peerAddress.score += 1
                try peerAddress.save(db)
            }
        }
    }

    func deletePeerAddress(byIp ip: String) {
        _ = try! dbPool.write { db in
            try PeerAddress.filter(PeerAddress.Columns.ip == ip).deleteAll(db)
        }
    }

    // BlockHash

    var blockchainBlockHashes: [BlockHash] {
        return try! dbPool.read { db in
            try BlockHash.filter(BlockHash.Columns.height == 0).fetchAll(db)
        }
    }

    var lastBlockchainBlockHash: BlockHash? {
        return try! dbPool.read { db in
            try BlockHash.filter(BlockHash.Columns.height == 0).order(BlockHash.Columns.sequence.desc).fetchOne(db)
        }
    }

    var lastBlockHash: BlockHash? {
        return try! dbPool.read { db in
            try BlockHash.order(BlockHash.Columns.sequence.desc).fetchOne(db)
        }
    }

    var blockHashHeaderHashes: [Data] {
        return try! dbPool.read { db in
            let rows = try Row.fetchCursor(db, "SELECT headerHash from blockHashes")
            var hashes = [Data]()

            while let row = try rows.next() {
                hashes.append(row[0] as Data)
            }

            return hashes
        }
    }

    func blockHashHeaderHashHexes(except excludedHash: String) -> [String] {
        return try! dbPool.read { db in
            let rows = try Row.fetchCursor(db, "SELECT headerHashReversedHex from blockHashes WHERE headerHashReversedHex != ?", arguments: [excludedHash])
            var hexes = [String]()

            while let row = try rows.next() {
                hexes.append(row[0] as String)
            }

            return hexes
        }
    }

    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash] {
        return try! dbPool.read { db in
            try BlockHash.order(BlockHash.Columns.sequence.asc).order(BlockHash.Columns.height.asc).limit(limit).fetchAll(db)
        }
    }

    func add(blockHashes: [BlockHash]) {
        _ = try! dbPool.write { db in
            for blockHash in blockHashes {
                try blockHash.insert(db)
            }
        }
    }

    func deleteBlockHash(byHashHex hashHex: String) {
        _ = try! dbPool.write { db in
            try BlockHash.filter(BlockHash.Columns.headerHashReversedHex == hashHex).deleteAll(db)
        }
    }

    func deleteBlockchainBlockHashes() {
        _ = try! dbPool.write { db in
            try BlockHash.filter(BlockHash.Columns.height == 0).deleteAll(db)
        }
    }

    // Block

    var blocksCount: Int {
        return try! dbPool.read { db in
            try Block.fetchCount(db)
        }
    }

    var lastBlock: Block? {
        return try! dbPool.read { db in
            try Block.order(Block.Columns.height.desc).fetchOne(db)
        }
    }

    func blocksCount(reversedHeaderHashHexes: [String]) -> Int {
        return try! dbPool.read { db in
            try Block.filter(reversedHeaderHashHexes.contains(Block.Columns.headerHashReversedHex)).fetchCount(db)
        }
    }

    func save(block: Block) {
        _ = try! dbPool.write { db in
            try block.insert(db)
        }
    }

    func blocks(heightGreaterThan leastHeight: Int, sortedBy sortField: Block.Columns, limit: Int) -> [Block] {
        return try! dbPool.read { db in
            try Block.filter(Block.Columns.height > leastHeight).order(sortField.desc).limit(limit).fetchAll(db)
        }
    }

    func blocks(from startHeight: Int, to endHeight: Int, ascending: Bool) -> [Block] {
        return try! dbPool.read { db in
            try Block.filter(Block.Columns.height >= startHeight).filter(Block.Columns.height <= endHeight).order(ascending ? Block.Columns.height.asc : Block.Columns.height.desc).fetchAll(db)
        }
    }

    func blocks(byHexes hexes: [String]) -> [Block] {
        return try! dbPool.read { db in
            try Block.filter(hexes.contains(Block.Columns.headerHashReversedHex)).fetchAll(db)
        }
    }

    func blocks(heightGreaterThanOrEqualTo height: Int, stale: Bool) -> [Block] {
        return try! dbPool.read { db in
            try Block.filter(Block.Columns.stale == stale).filter(Block.Columns.height >= height).fetchAll(db)
        }
    }

    func blocks(stale: Bool) -> [Block] {
        return try! dbPool.read { db in
            try Block.filter(Block.Columns.stale == stale).fetchAll(db)
        }
    }

    func block(byHeight height: Int) -> Block? {
        return try! dbPool.read { db in
            try Block.filter(Block.Columns.height == height).fetchOne(db)
        }
    }

    func block(byHashHex hex: String) -> Block? {
        return try! dbPool.read { db in
            try Block.filter(Block.Columns.headerHashReversedHex == hex).fetchOne(db)
        }
    }

    func block(stale: Bool, sortedHeight: String) -> Block? {
        return try! dbPool.read { db in
            let order = sortedHeight == "ASC" ? Block.Columns.height.asc : Block.Columns.height.desc
            return try Block.filter(Block.Columns.stale == stale).order(order).fetchOne(db)
        }
    }

    func add(block: Block) throws {
        _ = try! dbPool.write { db in
            try block.insert(db)
        }
    }

    func delete(blocks: [Block]) throws {
        _ = try! dbPool.write { db in
            for block in blocks {
                for transaction in transactions(ofBlock: block) {
                    try Input.filter(Input.Columns.transactionHashReversedHex == transaction.dataHashReversedHex).deleteAll(db)
                    try Output.filter(Output.Columns.transactionHashReversedHex == transaction.dataHashReversedHex).deleteAll(db)
                }

                try Transaction.filter(Transaction.Columns.blockHashReversedHex == block.headerHashReversedHex).deleteAll(db)
            }

            try Block.filter(blocks.map{$0.headerHashReversedHex}.contains(Block.Columns.headerHashReversedHex)).deleteAll(db)
        }
    }

    func unstaleAllBlocks() throws {
        _ = try! dbPool.write { db in
            try db.execute("UPDATE \(Block.databaseTableName) SET stale = true WHERE stale = false")
        }
    }

    // Transaction
    func transaction(byHashHex hex: String) -> Transaction? {
        return try! dbPool.read { db in
            try Transaction.filter(Transaction.Columns.dataHashReversedHex == hex).fetchOne(db)
        }
    }

    func transactions(ofBlock block: Block) -> [Transaction] {
        return try! dbPool.read { db in
            try Transaction.filter(Transaction.Columns.blockHashReversedHex == block.headerHashReversedHex).fetchAll(db)
        }
    }

    func newTransactions() -> [Transaction] {
        return try! dbPool.read { db in
            try Transaction.filter(Transaction.Columns.status == TransactionStatus.new).fetchAll(db)
        }
    }

    func newTransaction(byReversedHashHex hex: String) -> Transaction? {
        return try! dbPool.read { db in
            try Transaction
                    .filter(Transaction.Columns.status == TransactionStatus.new)
                    .filter(Transaction.Columns.dataHashReversedHex == hex)
                    .fetchOne(db)
        }
    }

    func relayedTransactionExists(byReversedHashHex hex: String) -> Bool {
        return try! dbPool.read { db in
            try Transaction
                    .filter(Transaction.Columns.status == TransactionStatus.relayed)
                    .filter(Transaction.Columns.dataHashReversedHex == hex)
                    .fetchCount(db) > 1
        }
    }

    func add(transaction: FullTransaction) throws {
        _ = try! dbPool.write { db in
            try transaction.header.insert(db)

            for input in transaction.inputs {
                try input.insert(db)
            }

            for output in transaction.outputs {
                try output.insert(db)
            }
        }
    }

    func update(transaction: Transaction) throws {
        _ = try! dbPool.write { db in
            try transaction.update(db)
        }
    }

    func fullInfo(forTransactions transactionsWithBlocks: [TransactionWithBlock]) -> [FullTransactionForInfo] {
        let transactionHashes: [String] = transactionsWithBlocks.map({ $0.transaction.dataHashReversedHex })
        var inputs = [InputWithPreviousOutput]()
        var outputs = [Output]()

        try! dbPool.read { db in
            for transactionHashChunks in transactionHashes.chunked(into: 999) {
                let inputC = Input.Columns.allCases.count
                let outputC = Output.Columns.allCases.count

                let adapter = ScopeAdapter([
                    "input": RangeRowAdapter(0..<inputC),
                    "output": RangeRowAdapter(inputC..<inputC + outputC)
                ])

                let sql = """
                          SELECT inputs.*, outputs.*
                          FROM inputs
                          LEFT JOIN outputs ON inputs.previousOutputTxReversedHex = outputs.transactionHashReversedHex AND inputs.previousOutputIndex = outputs."index"
                          WHERE inputs.transactionHashReversedHex IN (\(transactionHashChunks.map({ "'" + $0 + "'" }).joined(separator: ",")))
                          """
                let rows = try Row.fetchCursor(db, sql, adapter: adapter)

                while let row = try rows.next() {
                    inputs.append(InputWithPreviousOutput(input: row["input"], previousOutput: row["output"]))
                }

                outputs.append(contentsOf: try Output.filter(transactionHashChunks.contains(Output.Columns.transactionHashReversedHex)).fetchAll(db))
            }
        }

        var inputsByTransaction: [String: [InputWithPreviousOutput]] = Dictionary(grouping: inputs, by: { $0.input.transactionHashReversedHex })
        var outputsByTransaction: [String: [Output]] = Dictionary(grouping: outputs, by: { $0.transactionHashReversedHex })
        var results = [FullTransactionForInfo]()

        for transactionWithBlock in transactionsWithBlocks {
            let fullTransaction = FullTransactionForInfo(
                    transactionWithBlock: transactionWithBlock,
                    inputsWithPreviousOutputs: inputsByTransaction[transactionWithBlock.transaction.dataHashReversedHex] ?? [],
                    outputs: outputsByTransaction[transactionWithBlock.transaction.dataHashReversedHex] ?? []
            )

            results.append(fullTransaction)
        }

        return results
    }

    func fullTransactionsInfo(fromTimestamp: Int?, fromOrder: Int?, limit: Int?) -> [FullTransactionForInfo] {
        var transactions = [TransactionWithBlock]()

        try! dbPool.read { db in
            let transactionC = Transaction.Columns.allCases.count

            let adapter = ScopeAdapter([
                "transaction": RangeRowAdapter(0..<transactionC)
            ])

            var sql = """
                      SELECT transactions.*, blocks.height as blockHeight
                      FROM transactions
                      LEFT JOIN blocks ON transactions.blockHashReversedHex = blocks.headerHashReversedHex
                      ORDER BY transactions.timestamp DESC, transactions."order" DESC
                      """

            if let fromTimestamp = fromTimestamp, let fromOrder = fromOrder {
                sql = sql + "WHERE transactions.timestamp < \(fromTimestamp) OR (transactions.timestamp == \(fromTimestamp) AND transactions.\"order\" < \(fromOrder))"
            }

            let rows = try Row.fetchCursor(db, sql, adapter: adapter)

            while let row = try rows.next() {
                transactions.append(TransactionWithBlock(transaction: row["transaction"], blockHeight: row["blockHeight"]))
            }

        }

        return fullInfo(forTransactions: transactions)
    }


    // Inputs and Outputs

    func outputsWithPublicKeys() -> [OutputWithPublicKey] {
        return try! dbPool.read { db in
            let outputC = Output.Columns.allCases.count
            let publicKeyC = PublicKey.Columns.allCases.count
            let inputC = Input.Columns.allCases.count

            let adapter = ScopeAdapter([
                "output": RangeRowAdapter(0..<outputC),
                "publicKey": RangeRowAdapter(outputC..<outputC + publicKeyC),
                "input": RangeRowAdapter(outputC + publicKeyC..<outputC + publicKeyC + inputC)
            ])

            let sql = """
                      SELECT outputs.*, publicKeys.*, inputs.*, blocks.height AS blockHeight
                      FROM outputs 
                      INNER JOIN publicKeys ON outputs.publicKeyPath = publicKeys.path
                      LEFT JOIN inputs ON inputs.previousOutputTxReversedHex = outputs.transactionHashReversedHex AND inputs.previousOutputIndex = outputs."index"
                      LEFT JOIN transactions ON inputs.transactionHashReversedHex = transactions.dataHashReversedHex
                      LEFT JOIN blocks ON transactions.blockHashReversedHex = blocks.headerHashReversedHex
                      """
            let rows = try Row.fetchCursor(db, sql, adapter: adapter)

            var outputs = [OutputWithPublicKey]()
            while let row = try rows.next() {
                outputs.append(OutputWithPublicKey(output: row["output"], publicKey: row["publicKey"], spendingInput: row["input"], spendingBlockHeight: row["blockHeight"]))
            }

            return outputs
        }
    }

    func unspentOutputs() -> [UnspentOutput] {
        return try! dbPool.read { db in
            let inputs = try Input.fetchAll(db)

            let outputC = Output.Columns.allCases.count
            let publicKeyC = PublicKey.Columns.allCases.count
            let transactionC = Transaction.Columns.allCases.count

            let adapter = ScopeAdapter([
                "output": RangeRowAdapter(0..<outputC),
                "publicKey": RangeRowAdapter(outputC..<outputC + publicKeyC),
                "transaction": RangeRowAdapter(outputC + publicKeyC..<outputC + publicKeyC + transactionC)
            ])

            let sql = """
                      SELECT outputs.*, publicKeys.*, transactions.*, blocks.height AS blockHeight
                      FROM outputs 
                      INNER JOIN publicKeys ON outputs.publicKeyPath = publicKeys.path
                      INNER JOIN transactions ON outputs.transactionHashReversedHex = transactions.dataHashReversedHex
                      LEFT JOIN blocks ON transactions.blockHashReversedHex = blocks.headerHashReversedHex
                      WHERE outputs.scriptType != \(ScriptType.unknown.rawValue)
                      """
            let rows = try Row.fetchCursor(db, sql, adapter: adapter)

            var outputs = [UnspentOutput]()
            while let row = try rows.next() {
                let output: Output = row["output"]

                if !inputs.contains(where: { $0.previousOutputTxReversedHex == output.transactionHashReversedHex && $0.previousOutputIndex == output.index }) {
                    outputs.append(UnspentOutput(output: output, publicKey: row["publicKey"], transaction: row["transaction"], blockHeight: row["blockHeight"]))
                }
            }

            return outputs
        }
    }

    func inputs(ofTransaction transaction: Transaction) -> [Input] {
        return try! dbPool.read { db in
            try Input.filter(Input.Columns.transactionHashReversedHex == transaction.dataHashReversedHex).fetchAll(db)
        }
    }

    func outputs(ofTransaction transaction: Transaction) -> [Output] {
        return try! dbPool.read { db in
            try Output.filter(Output.Columns.transactionHashReversedHex == transaction.dataHashReversedHex).fetchAll(db)
        }
    }

    func previousOutput(ofInput input: Input) -> Output? {
        return try! dbPool.read { db in
            try Output
                    .filter(Output.Columns.transactionHashReversedHex == input.previousOutputTxReversedHex)
                    .filter(Output.Columns.index == input.previousOutputIndex)
                    .fetchOne(db)
        }
    }


    // SentTransaction
    func sentTransaction(byReversedHashHex hex: String) -> SentTransaction? {
        return try! dbPool.read { db in
            try SentTransaction.filter(SentTransaction.Columns.hashReversedHex == hex).fetchOne(db)
        }
    }

    func update(sentTransaction: SentTransaction) {
        _ = try! dbPool.write { db in
            try sentTransaction.update(db)
        }
    }

    func add(sentTransaction: SentTransaction) {
        _ = try! dbPool.write { db in
            try sentTransaction.insert(db)
        }
    }

    // PublicKeys
    func publicKeys() -> [PublicKey] {
        return try! dbPool.read { db in
            try PublicKey.fetchAll(db)
        }
    }

    func publicKey(byPath path: String) -> PublicKey? {
        return try! dbPool.read { db in
            try PublicKey.filter(PublicKey.Columns.path == path).fetchOne(db)
        }
    }

    func publicKey(byScriptHashForP2WPKH hash: Data) -> PublicKey? {
        return try! dbPool.read { db in
            try PublicKey.filter(PublicKey.Columns.scriptHashForP2WPKH == hash).fetchOne(db)
        }
    }

    func publicKey(byRawOrKeyHash hash: Data) -> PublicKey? {
        return try! dbPool.read { db in
            try PublicKey.filter(PublicKey.Columns.raw == hash || PublicKey.Columns.keyHash == hash).fetchOne(db)
        }
    }

    func add(publicKeys: [PublicKey]) {
        _ = try! dbPool.write { db in
            for publicKey in publicKeys {
                try publicKey.insert(db)
            }
        }
    }

    func publicKeysWithUsedState() -> [PublicKeyWithUsedState] {
        return try! dbPool.read { db in
            let publicKeyC = PublicKey.Columns.allCases.count

            let adapter = ScopeAdapter([
                "publicKey": RangeRowAdapter(0..<publicKeyC)
            ])

            let sql = """
                      SELECT publicKeys.*, outputs.transactionHashReversedHex
                      FROM publicKeys
                      LEFT JOIN outputs ON publicKeys.path = outputs.publicKeyPath
                      """

            let rows = try Row.fetchCursor(db, sql, adapter: adapter)
            var publicKeys = [PublicKeyWithUsedState]()
            while let row = try rows.next() {
                publicKeys.append(PublicKeyWithUsedState(publicKey: row["publicKey"], used: row["transactionHashReversedHex"] != nil))
            }

            return publicKeys
        }
    }

    // Clear

    func clear() throws {
        try clearGrdb()
    }

}
