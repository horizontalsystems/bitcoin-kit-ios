import RxSwift
import GRDB

class GrdbStorage {
    private let dbPool: DatabasePool

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

        return migrator
    }

}

extension GrdbStorage: IStorage {

    var feeRate: FeeRate {
        return try! dbPool.read { db in
            try FeeRate.fetchOne(db) ?? FeeRate.defaultFeeRate
        }
    }

    func save(feeRate: FeeRate) {
        _ = try? dbPool.write { db in
            try feeRate.insert(db)
        }
    }

    var initialRestored: Bool {
        get {
            return try! dbPool.read { db in
                let state = try BlockchainState.fetchOne(db) ?? BlockchainState()
                return state.initialRestored
            }
        }
        set {
            _ = try? dbPool.write { db in
                let state = try BlockchainState.fetchOne(db) ?? BlockchainState()
                state.initialRestored = newValue
                try state.insert(db)
            }
        }
    }

    func clear() {
        _ = try? dbPool.write { db in
            try FeeRate.deleteAll(db)
            try BlockchainState.deleteAll(db)
        }
    }

}
