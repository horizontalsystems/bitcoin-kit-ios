import GRDB
import BitcoinCore

class DashGrdbStorage: GrdbStorage {

    override var migrator: GRDB.DatabaseMigrator {
        var migrator = super.migrator

        migrator.registerMigration("createMasternodes") { db in
            try db.create(table: Masternode.databaseTableName) { t in
                t.column(Masternode.Columns.proRegTxHash.name, .text).notNull()
                t.column(Masternode.Columns.confirmedHash.name, .text).notNull()
                t.column(Masternode.Columns.confirmedHashWithProRegTxHash.name, .text).notNull()
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

        migrator.registerMigration("createInstantTransactionOutputs") { db in
            try db.create(table: InstantTransactionInput.databaseTableName) { t in
                t.column(InstantTransactionInput.Columns.txHash.name, .text).notNull()
                t.column(InstantTransactionInput.Columns.inputTxHash.name, .text).notNull()
                t.column(InstantTransactionInput.Columns.timeCreated.name, .integer).notNull()
                t.column(InstantTransactionInput.Columns.voteCount.name, .integer).notNull()
                t.column(InstantTransactionInput.Columns.blockHeight.name, .integer)

                t.primaryKey([InstantTransactionInput.Columns.inputTxHash.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createInstantTransactionHashes") { db in
            try db.create(table: InstantTransactionHash.databaseTableName) { t in
                t.column(InstantTransactionHash.Columns.txHash.name, .text).notNull()

                t.primaryKey([InstantTransactionHash.Columns.txHash.name], onConflict: .ignore)
            }
        }
        migrator.registerMigration("createQuorums") { db in
            try db.create(table: Quorum.databaseTableName) { t in
                t.column(Quorum.Columns.hash.name, .text).notNull()
                t.column(Quorum.Columns.version.name, .integer).notNull()
                t.column(Quorum.Columns.type.name, .integer).notNull()
                t.column(Quorum.Columns.quorumHash.name, .text).notNull()
                t.column(Quorum.Columns.typeWithQuorumHash.name, .text).notNull()
                t.column(Quorum.Columns.signers.name, .text).notNull()
                t.column(Quorum.Columns.validMembers.name, .text).notNull()
                t.column(Quorum.Columns.quorumPublicKey.name, .text).notNull()
                t.column(Quorum.Columns.quorumVvecHash.name, .text).notNull()
                t.column(Quorum.Columns.quorumSig.name, .text).notNull()
                t.column(Quorum.Columns.sig.name, .text).notNull()

                t.primaryKey([Quorum.Columns.hash.name], onConflict: .replace)
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

    var quorums: [Quorum] {
        get {
            return try! dbPool.read { db in
                try Quorum.fetchAll(db)
            }
        }
        set {
            _ = try? dbPool.write { db in
                try Quorum.deleteAll(db)
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

    func quorums(by type: QuorumType) -> [Quorum] {
        return try! dbPool.read { db in
            try Quorum.filter(Quorum.Columns.type == type.rawValue).fetchAll(db)
        }
    }

    func instantTransactionHashes() -> [Data] {
        return try! dbPool.read { db in
            try InstantTransactionHash.fetchAll(db).map { $0.txHash }
        }
    }

    func add(instantTransactionHash: Data) {
        _ = try? dbPool.write { db in
            try InstantTransactionHash(txHash: instantTransactionHash).insert(db)
        }
    }

    func add(instantTransactionInput: InstantTransactionInput) {
        _ = try? dbPool.write { db in
            try instantTransactionInput.insert(db)
        }
    }

    func removeInstantTransactionInputs(for txHash: Data) {
        _ = try! dbPool.write { db in
            try InstantTransactionInput.filter(InstantTransactionInput.Columns.txHash == txHash).deleteAll(db)
        }
    }

    func instantTransactionInputs(for txHash: Data) -> [InstantTransactionInput] {
        return try! dbPool.read { db in
            try InstantTransactionInput.filter(InstantTransactionInput.Columns.txHash == txHash).fetchAll(db)
        }
    }

    func instantTransactionInput(for inputTxHash: Data) -> InstantTransactionInput? {
        return try! dbPool.read { db in
            try InstantTransactionInput.filter(InstantTransactionInput.Columns.inputTxHash == inputTxHash).fetchOne(db)
        }
    }

}