import RxSwift
import GRDB
import RealmSwift

public class GrdbStorage {
    var dbPool: DatabasePool
    private let databaseName: String
    private var databaseURL: URL

    private let realmFactory: IRealmFactory

    public init(databaseFileName: String, realmFactory: IRealmFactory) {
        self.databaseName = databaseFileName
        self.realmFactory = realmFactory

        databaseURL = try! FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("\(databaseName).sqlite")

        dbPool = try! DatabasePool(path: databaseURL.path)
        try? migrator.migrate(dbPool)
    }

    private func initDatabase() {
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
                t.column(BlockHash.Columns.reversedHeaderHashHex.name, .text).notNull()
                t.column(BlockHash.Columns.headerHash.name, .blob).notNull()
                t.column(BlockHash.Columns.height.name, .integer).notNull()
                t.column(BlockHash.Columns.sequence.name, .integer).notNull()

                t.primaryKey([BlockHash.Columns.reversedHeaderHashHex.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createSentTransactions") { db in
            try db.create(table: SentTransaction.databaseTableName) { t in
                t.column(SentTransaction.Columns.reversedHashHex.name, .text).notNull()
                t.column(SentTransaction.Columns.firstSendTime.name, .double).notNull()
                t.column(SentTransaction.Columns.lastSendTime.name, .double).notNull()
                t.column(SentTransaction.Columns.retriesCount.name, .integer).notNull()

                t.primaryKey([SentTransaction.Columns.reversedHashHex.name], onConflict: .replace)
            }
        }

        return migrator
    }

    func clearGrdb() throws {
        try FileManager.default.removeItem(at: databaseURL)

        initDatabase()
    }

}

extension GrdbStorage: IStorage {
    var realm: Realm {
        return realmFactory.realm
    }
    // FeeRate

    var feeRate: FeeRate? {
        return try! dbPool.read { db in
            try FeeRate.fetchOne(db)
        }
    }

    func set(feeRate: FeeRate) {
        _ = try? dbPool.write { db in
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
        _ = try? dbPool.write { db in
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
        _ = try? dbPool.write { db in
            for peerAddress in peerAddresses {
                try peerAddress.insert(db)
            }
        }
    }

    func increasePeerAddressScore(ip: String) {
        _ = try? dbPool.write { db in
            if let peerAddress = try PeerAddress.filter(PeerAddress.Columns.ip == ip).fetchOne(db) {
                peerAddress.score += 1
                try peerAddress.save(db)
            }
        }
    }

    func deletePeerAddress(byIp ip: String) {
        _ = try? dbPool.write { db in
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
            let rows = try Row.fetchCursor(db, "SELECT reversedHeaderHashHex from blockHashes WHERE reversedHeaderHashHex != ?", arguments: [excludedHash])
            var hexes = [String]()

            while let row = try rows.next() {
                hexes.append(row[0] as String)
            }

            return hexes
        }
    }

    func blockHashes(filters: [(fieldName: BlockHash.Columns, value: Any, equal: Bool)], orders: [(fieldName: BlockHash.Columns, ascending: Bool)]) -> [BlockHash] {
        return try! dbPool.read { db in
            var request = BlockHash.all()

            for (fieldName, value, equal) in filters {
                let predicate = equal ? fieldName == DatabaseValue(value: value) : fieldName != DatabaseValue(value: value)
                request = request.filter(predicate)
            }

            return try request.fetchAll(db)
        }
    }

    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash] {
        return try! dbPool.read { db in
            try BlockHash.order(BlockHash.Columns.sequence.asc).order(BlockHash.Columns.height.asc).limit(limit).fetchAll(db)
        }
    }

    func add(blockHashes: [BlockHash]) {
        _ = try? dbPool.write { db in
            for blockHash in blockHashes {
                try blockHash.insert(db)
            }
        }
    }

    func deleteBlockHash(byHashHex hashHex: String) {
        _ = try? dbPool.write { db in
            try BlockHash.filter(BlockHash.Columns.reversedHeaderHashHex == hashHex).deleteAll(db)
        }
    }

    func deleteBlockchainBlockHashes() {
        _ = try? dbPool.write { db in
            try BlockHash.filter(BlockHash.Columns.height == 0).deleteAll(db)
        }
    }

    // Block

    var blocksCount: Int {
        return realmFactory.realm.objects(Block.self).count
    }

    var lastBlock: Block? {
        return realmFactory.realm.objects(Block.self).sorted(byKeyPath: "height").last
    }

    func blocksCount(reversedHeaderHashHexes: [String]) -> Int {
        return realmFactory.realm.objects(Block.self).filter(NSPredicate(format: "reversedHeaderHashHex IN %@", reversedHeaderHashHexes)).count
    }

    func save(block: Block) {
        let realm = realmFactory.realm
        try? realm.write {
            realm.add(block)
        }
    }

    func blocks(heightGreaterThan leastHeight: Int, sortedBy sortField: String, limit: Int) -> [Block] {
        return Array(realmFactory.realm.objects(Block.self).filter("height > %@", leastHeight).sorted(byKeyPath: sortField, ascending: false).prefix(limit))
    }

    func blocks(byHexes hexes: [String], realm: Realm) -> Results<Block> {
        return realm.objects(Block.self).filter(NSPredicate(format: "reversedHeaderHashHex IN %@", hexes))
    }

    func block(byHeight height: Int32) -> Block? {
        return realmFactory.realm.objects(Block.self).filter("height = %@", height).first
    }

    func block(byHeaderHash hash: Data) -> Block? {
        return realmFactory.realm.objects(Block.self).filter("headerHash == %@", hash).first
    }


    // Transaction
    func newTransactions() -> [Transaction] {
        return Array(realmFactory.realm.objects(Transaction.self).filter("status = %@", TransactionStatus.new.rawValue))
    }

    func newTransaction(byReversedHashHex hex: String) -> Transaction? {
        return realmFactory.realm.objects(Transaction.self)
                .filter("reversedHashHex = %@ AND status = %@", hex, TransactionStatus.new.rawValue)
                .first
    }

    func relayedTransactionExists(byReversedHashHex hex: String) -> Bool {
        return !realmFactory.realm.objects(Transaction.self).filter("reversedHashHex = %@ AND status = %@", hex, TransactionStatus.relayed.rawValue).isEmpty
    }

    // SentTransaction
    func sentTransaction(byReversedHashHex hex: String) -> SentTransaction? {
        return try! dbPool.read { db in
            try SentTransaction.filter(SentTransaction.Columns.reversedHashHex == hex).fetchOne(db)
        }
    }

    func update(sentTransaction: SentTransaction) {
        _ = try? dbPool.write { db in
            try sentTransaction.update(db)
        }
    }

    func add(sentTransaction: SentTransaction) {
        _ = try? dbPool.write { db in
            try sentTransaction.insert(db)
        }
    }

    // Clear

    func clear() throws {
        try clearGrdb()

        let realm = realmFactory.realm

        try realm.write {
            realm.deleteAll()
        }
    }

    func inTransaction(_ block: ((_ realm: Realm) throws -> Void)) throws {
        let realm = realmFactory.realm

        try realm.write {
            try block(realm)
        }
    }

}
