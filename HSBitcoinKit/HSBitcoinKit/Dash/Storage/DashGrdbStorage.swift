import GRDB

class DashGrdbStorage: GrdbStorage {

    override var migrator: GRDB.DatabaseMigrator {
        var migrator = super.migrator

        migrator.registerMigration("createMasternodes") { db in
            try db.create(table: Masternode.databaseTableName) { t in
                t.column(Masternode.Columns.proRegTxHash.name, .text).notNull()
                t.column(Masternode.Columns.confirmedHash.name, .text).notNull()
                t.column(Masternode.Columns.ipAddress.name, .text).notNull()
                t.column(Masternode.Columns.port.name, .integer).notNull()
                t.column(Masternode.Columns.pubKeyOperator.name, .date).notNull()
                t.column(Masternode.Columns.keyIDVoting.name, .date).notNull()
                t.column(Masternode.Columns.isValid.name, .boolean).notNull()

                t.primaryKey([Masternode.Columns.proRegTxHash.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createMasternodeListState") { db in
            try db.create(table: MasternodeListState.databaseTableName) { t in
                t.column(MasternodeListState.Columns.primaryKey.name, .text).notNull()
                t.column(MasternodeListState.Columns.baseBlockHash.name, .text).notNull()

                t.primaryKey([MasternodeListState.Columns.primaryKey.name], onConflict: .replace)
            }
        }

        return migrator
    }
}

extension DashGrdbStorage: IDashStorage {

    var masternodes: [Masternode] {
        get {
            return try! dbPool.read { db in
                try Masternode.fetchAll(db)
            }
        }
        set {
            _ = try? dbPool.write { db in
                try Masternode.deleteAll(db)
                try newValue.forEach { try $0.insert(db) }
            }
        }
    }

    var masternodeListState: MasternodeListState? {
        get {
            return try! dbPool.read { db in
                try MasternodeListState.fetchOne(db)
            }
        }
        set {
            guard let newValue = newValue else {
                _ = try? dbPool.write { db in
                    try MasternodeListState.deleteAll(db)
                }
                return
            }
            _ = try? dbPool.write { db in
                try newValue.insert(db)
            }
        }
    }

}