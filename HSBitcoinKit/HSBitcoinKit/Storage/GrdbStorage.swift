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

        migrator.registerMigration("createPeerAddresses") { db in
            try db.create(table: PeerAddress.databaseTableName) { t in
                t.column(PeerAddress.Columns.ip.name, .text).notNull()
                t.column(PeerAddress.Columns.score.name, .integer).notNull()

                t.primaryKey([PeerAddress.Columns.ip.name], onConflict: .replace)
            }
        }

        return migrator
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

    // Clear

    func clear() {
        _ = try? dbPool.write { db in
            try FeeRate.deleteAll(db)
            try BlockchainState.deleteAll(db)
            try PeerAddress.deleteAll(db)
        }
    }

}
