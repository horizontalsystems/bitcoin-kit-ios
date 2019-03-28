import RxSwift
import GRDB

class GrdbStorage {
    private let dbPool: DatabasePool
    private var dbsInTransaction = [Int: Database]()

    init(databaseFileName: String) {
        let databaseURL = try! FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("\(databaseFileName).sqlite")

        dbPool = try! DatabasePool(path: databaseURL.path)

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

        return migrator
    }

    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        if let db = dbsInTransaction[Thread.current.hash] {
            return try block(db)
        }

        return try dbPool.read { db in
            try block(db)
        }
    }

    public func write(_ block: (Database) throws -> Void) throws {
        if let db = dbsInTransaction[Thread.current.hash] {
            _ = try block(db)
            return
        }

        _ = try dbPool.write { db in
            try block(db)
        }
    }

}

extension GrdbStorage: IStorage {
    // FeeRate

    var feeRate: FeeRate? {
        return try! read { db in
            try FeeRate.fetchOne(db)
        }
    }

    func set(feeRate: FeeRate) {
        try? write { db in
            try feeRate.insert(db)
        }
    }

    // BlockchainState

    var initialRestored: Bool? {
        return try! read { db in
            try BlockchainState.fetchOne(db)?.initialRestored
        }
    }

    func set(initialRestored: Bool) {
        try? write { db in
            let state = try BlockchainState.fetchOne(db) ?? BlockchainState()
            state.initialRestored = initialRestored
            try state.insert(db)
        }
    }

    // PeerAddress

    func existingPeerAddresses(fromIps ips: [String]) -> [PeerAddress] {
        return try! read { db in
            try PeerAddress
                    .filter(ips.contains(PeerAddress.Columns.ip))
                    .fetchAll(db)
        }
    }

    func leastScorePeerAddress(excludingIps: [String]) -> PeerAddress? {
        return try! read { db in
            try PeerAddress
                    .filter(!excludingIps.contains(PeerAddress.Columns.ip))
                    .order(PeerAddress.Columns.score.asc)
                    .fetchOne(db)
        }
    }

    func save(peerAddresses: [PeerAddress]) {
        try? write { db in
            for peerAddress in peerAddresses {
                try peerAddress.insert(db)
            }
        }
    }

    func increasePeerAddressScore(ip: String) {
        try? write { db in
            if let peerAddress = try PeerAddress.filter(PeerAddress.Columns.ip == ip).fetchOne(db) {
                peerAddress.score += 1
                try peerAddress.save(db)
            }
        }
    }

    func deletePeerAddress(byIp ip: String) {
        try? write { db in
            try PeerAddress.filter(PeerAddress.Columns.ip == ip).deleteAll(db)
        }
    }

    // BlockHash

    var blockchainBlockHashes: [BlockHash] {
        return try! read { db in
            try BlockHash.filter(BlockHash.Columns.height == 0).fetchAll(db)
        }
    }

    var lastBlockchainBlockHash: BlockHash? {
        return try! read { db in
            try BlockHash.filter(BlockHash.Columns.height == 0).order(BlockHash.Columns.sequence.desc).fetchOne(db)
        }
    }

    var lastBlockHash: BlockHash? {
        return try! read { db in
            try BlockHash.order(BlockHash.Columns.sequence.desc).fetchOne(db)
        }
    }

    var blockHashHeaderHashes: [Data] {
        return try! read { db in
            let rows = try Row.fetchCursor(db, "SELECT headerHash from blockHashes")
            var hashes = [Data]()

            while let row = try rows.next() {
                hashes.append(row[0] as Data)
            }

            return hashes
        }
    }

    func blockHashHeaderHashHexes(except excludedHash: String) -> [String] {
        return try! read { db in
            let rows = try Row.fetchCursor(db, "SELECT headerHashReversedHex from blockHashes WHERE headerHashReversedHex != ?", arguments: [excludedHash])
            var hexes = [String]()

            while let row = try rows.next() {
                hexes.append(row[0] as String)
            }

            return hexes
        }
    }

    func blockHashes(filters: [(fieldName: BlockHash.Columns, value: Any, equal: Bool)], orders: [(fieldName: BlockHash.Columns, ascending: Bool)]) -> [BlockHash] {
        return try! read { db in
            var request = BlockHash.all()

            for (fieldName, value, equal) in filters {
                let predicate = equal ? fieldName == DatabaseValue(value: value) : fieldName != DatabaseValue(value: value)
                request = request.filter(predicate)
            }

            return try request.fetchAll(db)
        }
    }

    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash] {
        return try! read { db in
            try BlockHash.order(BlockHash.Columns.sequence.asc).order(BlockHash.Columns.height.asc).limit(limit).fetchAll(db)
        }
    }

    func add(blockHashes: [BlockHash]) {
        try? write { db in
            for blockHash in blockHashes {
                try blockHash.insert(db)
            }
        }
    }

    func deleteBlockHash(byHashHex hashHex: String) {
        try? write { db in
            try BlockHash.filter(BlockHash.Columns.headerHashReversedHex == hashHex).deleteAll(db)
        }
    }

    func deleteBlockchainBlockHashes() {
        try? write { db in
            try BlockHash.filter(BlockHash.Columns.height == 0).deleteAll(db)
        }
    }

    // Block

    var blocksCount: Int {
        return try! read { db in
            try Block.fetchCount(db)
        }
    }

    var firstBlock: Block? {
        return try! read { db in
            try Block.order(Block.Columns.height.asc).fetchOne(db)
        }
    }

    var lastBlock: Block? {
        return try! read { db in
            try Block.order(Block.Columns.height.desc).fetchOne(db)
        }
    }

    func blocksCount(reversedHeaderHashHexes: [String]) -> Int {
        return try! read { db in
            try Block.filter(reversedHeaderHashHexes.contains(Block.Columns.headerHashReversedHex)).fetchCount(db)
        }
    }

    func save(block: Block) {
        try? write { db in
            try block.insert(db)
        }
    }

    func blocks(heightGreaterThan leastHeight: Int, sortedBy sortField: Block.Columns, limit: Int) -> [Block] {
        return try! read { db in
            try Block.filter(Block.Columns.height > leastHeight).order(sortField.desc).limit(limit).fetchAll(db)
        }
    }

    func blocks(byHexes hexes: [String]) -> [Block] {
        return try! read { db in
            try Block.filter(hexes.contains(Block.Columns.headerHashReversedHex)).fetchAll(db)
        }
    }

    func blocks(heightGreaterThanOrEqualTo height: Int, stale: Bool) -> [Block] {
        return try! read { db in
            try Block.filter(Block.Columns.stale == stale).filter(Block.Columns.height >= height).fetchAll(db)
        }
    }

    func blocks(stale: Bool) -> [Block] {
        return try! read { db in
            try Block.filter(Block.Columns.stale == stale).fetchAll(db)
        }
    }

    func block(byHeight height: Int32) -> Block? {
        return try! read { db in
            try Block.filter(Block.Columns.height == height).fetchOne(db)
        }
    }

    func block(byHashHex hex: String) -> Block? {
        return try! read { db in
            try Block.filter(Block.Columns.headerHashReversedHex == hex).fetchOne(db)
        }
    }

    func block(stale: Bool, sortedHeight: String) -> Block? {
        return try! read { db in
            let order = sortedHeight == "ASC" ? Block.Columns.height.asc : Block.Columns.height.desc
            return try Block.filter(Block.Columns.stale == stale).order(order).fetchOne(db)
        }
    }

    func add(block: Block) throws {
        try? write { db in
            try block.insert(db)
        }
    }

    func update(block: Block) throws {
        try? write { db in
            try block.update(db)
        }
    }

    func delete(blocks: [Block]) throws {
        try? write { db in
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

    // Transaction
    func transaction(byHashHex hex: String) -> Transaction? {
        return try! read { db in
            try Transaction.filter(Transaction.Columns.dataHashReversedHex == hex).fetchOne(db)
        }
    }

    func transactions(sortedBy: Transaction.Columns, secondSortedBy: Transaction.Columns, ascending: Bool) -> [Transaction] {
        return try! read { db in
            var sortItems = [SQLOrderingTerm]()

            if ascending {
                sortItems.append(contentsOf: [sortedBy.asc, secondSortedBy.asc])
            } else {
                sortItems.append(contentsOf: [sortedBy.desc, secondSortedBy.desc])
            }

            return try Transaction.order(sortItems).fetchAll(db)
        }
    }

    func transactions(ofBlock block: Block) -> [Transaction] {
        return try! read { db in
            try Transaction.filter(Transaction.Columns.blockHashReversedHex == block.headerHashReversedHex).fetchAll(db)
        }
    }

    func newTransactions() -> [Transaction] {
        return try! read { db in
            try Transaction.filter(Transaction.Columns.status == TransactionStatus.new).fetchAll(db)
        }
    }

    func newTransaction(byReversedHashHex hex: String) -> Transaction? {
        return try! read { db in
            try Transaction
                    .filter(Transaction.Columns.status == TransactionStatus.new)
                    .filter(Transaction.Columns.dataHashReversedHex == hex)
                    .fetchOne(db)
        }
    }

    func relayedTransactionExists(byReversedHashHex hex: String) -> Bool {
        return try! read { db in
            try Transaction
                    .filter(Transaction.Columns.status == TransactionStatus.relayed)
                    .filter(Transaction.Columns.dataHashReversedHex == hex)
                    .fetchCount(db) > 1
        }
    }

    func add(transaction: FullTransaction) throws {
        try? write { db in
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
        try? write { db in
            try transaction.update(db)
        }
    }

    // Inputs and Outputs
    func outputsWithPublicKeys() -> [OutputWithPublicKey] {
        return try! read { db in
            let outputC = Output.Columns.allCases.count
            let publicKeyC = PublicKey.Columns.allCases.count

            let adapter = ScopeAdapter([
                "output": RangeRowAdapter(0..<outputC),
                "publicKey": RangeRowAdapter(outputC..<outputC + publicKeyC)
            ])

            let sql = """
                      SELECT outputs.*, publicKeys.*
                      FROM outputs 
                      INNER JOIN publicKeys ON outputs.publicKeyPath = publicKeys.path
                      """
            let rows = try Row.fetchCursor(db, sql, adapter: adapter)

            var outputs = [OutputWithPublicKey]()
            while let row = try rows.next() {
                outputs.append(OutputWithPublicKey(output: row["output"], publicKey: row["publicKey"]))
            }

            return outputs
        }
    }

    func unspentOutputs() -> [UnspentOutput] {
        return try! read { db in
            let inputs = try Input.fetchAll(db)

            let outputC = Output.Columns.allCases.count
            let publicKeyC = PublicKey.Columns.allCases.count
            let transactionC = Transaction.Columns.allCases.count
            let blockC = Block.Columns.allCases.count

            let adapter = ScopeAdapter([
                "output": RangeRowAdapter(0..<outputC),
                "publicKey": RangeRowAdapter(outputC..<outputC + publicKeyC),
                "transaction": RangeRowAdapter(outputC + publicKeyC..<outputC + publicKeyC + transactionC),
                "block": RangeRowAdapter(outputC + publicKeyC + transactionC..<outputC + publicKeyC + transactionC + blockC),
            ])

            let sql = """
                      SELECT outputs.*, publicKeys.*, transactions.*, blocks.* 
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
                    outputs.append(UnspentOutput(output: output, publicKey: row["publicKey"], transaction: row["transaction"], block: row["block"]))
                }
            }

            return outputs
        }
    }

    func inputs(ofTransaction transaction: Transaction) -> [Input] {
        return try! read { db in
            try Input.filter(Input.Columns.transactionHashReversedHex == transaction.dataHashReversedHex).fetchAll(db)
        }
    }

    func inputsWithBlock(ofOutput output: Output) -> [InputWithBlock] {
        return try! read { db in
            let inputC = Input.Columns.allCases.count
            let blockC = Block.Columns.allCases.count

            let adapter = ScopeAdapter([
                "input": RangeRowAdapter(0..<inputC),
                "block": RangeRowAdapter(inputC..<inputC + blockC),
            ])

            let sql = """
                      SELECT inputs.*, blocks.* 
                      FROM inputs 
                      INNER JOIN transactions ON inputs.transactionHashReversedHex = transactions.dataHashReversedHex
                      LEFT JOIN blocks ON transactions.blockHashReversedHex = blocks.headerHashReversedHex
                      WHERE inputs.previousOutputTxReversedHex = \(output.transactionHashReversedHex) AND inputs.previousOutputIndex = \(output.index)
                      """
            let rows = try Row.fetchCursor(db, sql, adapter: adapter)

            var inputs = [InputWithBlock]()
            while let row = try rows.next() {
                inputs.append(InputWithBlock(input: row["input"], block: row["block"]))
            }

            return inputs
        }
    }

    func outputs(ofTransaction transaction: Transaction) -> [Output] {
        return try! read { db in
            try Output.filter(Output.Columns.transactionHashReversedHex == transaction.dataHashReversedHex).fetchAll(db)
        }
    }

    func previousOutput(ofInput input: Input) -> Output? {
        return try! read { db in
            try Output
                    .filter(Output.Columns.transactionHashReversedHex == input.previousOutputTxReversedHex)
                    .filter(Output.Columns.index == input.previousOutputIndex)
                    .fetchOne(db)
        }
    }

    func hasInputs(ofOutput output: Output) -> Bool {
        return try! read { db in
            try Input
                    .filter(Input.Columns.previousOutputTxReversedHex == output.transactionHashReversedHex)
                    .filter(Input.Columns.previousOutputIndex == output.index)
                    .fetchCount(db) > 1
        }
    }

    func hasOutputs(ofPublicKey publicKey: PublicKey) -> Bool {
        return try! read { db in
            try Output.filter(Output.Columns.publicKeyPath == publicKey.path).fetchCount(db) > 0
        }
    }

    // SentTransaction
    func sentTransaction(byReversedHashHex hex: String) -> SentTransaction? {
        return try! read { db in
            try SentTransaction.filter(SentTransaction.Columns.hashReversedHex == hex).fetchOne(db)
        }
    }

    func update(sentTransaction: SentTransaction) {
        try? write { db in
            try sentTransaction.update(db)
        }
    }

    func add(sentTransaction: SentTransaction) {
        try? write { db in
            try sentTransaction.insert(db)
        }
    }

    // PublicKeys
    func publicKeys() -> [PublicKey] {
        return try! read { db in
            try PublicKey.fetchAll(db)
        }
    }

    func publicKey(byPath path: String) -> PublicKey? {
        return try! read { db in
            try PublicKey.filter(PublicKey.Columns.path == path).fetchOne(db)
        }
    }

    func publicKey(byScriptHashForP2WPKH hash: Data) -> PublicKey? {
        return try! read { db in
            try PublicKey.filter(PublicKey.Columns.scriptHashForP2WPKH == hash).fetchOne(db)
        }
    }

    func publicKey(byRawOrKeyHash hash: Data) -> PublicKey? {
        return try! read { db in
            try PublicKey.filter(PublicKey.Columns.raw == hash || PublicKey.Columns.keyHash == hash).fetchOne(db)
        }
    }

    func add(publicKeys: [PublicKey]) {
        try? write { db in
            for publicKey in publicKeys {
                try publicKey.insert(db)
            }
        }
    }

    // Clear

    func clear() throws {
        _ = try dbPool.write { db in
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

    func inTransaction(_ block: (() throws -> Void)) throws {
        let currentThreadHash = Thread.current.hash

        if let _ = dbsInTransaction[currentThreadHash] {
            try block()
            return
        }

        defer {
            dbsInTransaction.removeValue(forKey: currentThreadHash)
        }

        _ = try dbPool.write { db in
            self.dbsInTransaction[currentThreadHash] = db
            try block()
        }
    }

}
