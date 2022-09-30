import Foundation
import GRDB

class Quorum: Record {
    let dataHash: Data
    let version: UInt16
    let type: UInt8
    let quorumHash: Data
    let typeWithQuorumHash: Data
    let quorumIndex: UInt16?
    let signers: Data
    let validMembers: Data
    let quorumPublicKey: Data
    let quorumVvecHash: Data
    let quorumSig: Data
    let sig: Data

    override class var databaseTableName: String {
        "quorums"
    }

    enum Columns: String, ColumnExpression {
        case hash
        case version
        case type
        case quorumHash
        case typeWithQuorumHash
        case quorumIndex
        case signers
        case validMembers
        case quorumPublicKey
        case quorumVvecHash
        case quorumSig
        case sig
    }

    required init(row: Row) {
        dataHash = row[Columns.hash]
        version = row[Columns.version]
        type = row[Columns.type]
        quorumHash = row[Columns.quorumHash]
        typeWithQuorumHash = row[Columns.typeWithQuorumHash]
        quorumIndex = row[Columns.quorumIndex]
        signers = row[Columns.signers]
        validMembers = row[Columns.validMembers]
        quorumPublicKey = row[Columns.quorumPublicKey]
        quorumVvecHash = row[Columns.quorumVvecHash]
        quorumSig = row[Columns.quorumSig]
        sig = row[Columns.sig]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.hash] = dataHash
        container[Columns.version] = version
        container[Columns.type] = type
        container[Columns.quorumHash] = quorumHash
        container[Columns.typeWithQuorumHash] = typeWithQuorumHash
        container[Columns.quorumIndex] = quorumIndex
        container[Columns.signers] = signers
        container[Columns.validMembers] = validMembers
        container[Columns.quorumPublicKey] = quorumPublicKey
        container[Columns.quorumVvecHash] = quorumVvecHash
        container[Columns.quorumSig] = quorumSig
        container[Columns.sig] = sig
    }

    init(hash: Data, version: UInt16, type: UInt8, quorumHash: Data, typeWithQuorumHash: Data, quorumIndex: UInt16?, signers: Data, validMembers: Data, quorumPublicKey: Data, quorumVvecHash: Data, quorumSig: Data, sig: Data) {
        self.dataHash = hash
        self.version = version
        self.type = type
        self.quorumHash = quorumHash
        self.typeWithQuorumHash = typeWithQuorumHash
        self.quorumIndex = quorumIndex
        self.signers = signers
        self.validMembers = validMembers
        self.quorumPublicKey = quorumPublicKey
        self.quorumVvecHash = quorumVvecHash
        self.quorumSig = quorumSig
        self.sig = sig

        super.init()
    }

}

extension Quorum: Hashable, Comparable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(dataHash)
    }

    public static func ==(lhs: Quorum, rhs: Quorum) -> Bool {
        return lhs.dataHash == rhs.dataHash
    }

    public static func <(lhs: Quorum, rhs: Quorum) -> Bool {
        return lhs.dataHash < rhs.dataHash
    }

}
