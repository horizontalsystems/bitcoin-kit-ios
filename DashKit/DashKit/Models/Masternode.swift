import GRDB

class Masternode: Record {
    let proRegTxHash: Data
    let confirmedHash: Data
    var confirmedHashWithProRegTxHash: Data
    let ipAddress: Data
    let port: UInt16
    let pubKeyOperator: Data
    let keyIDVoting: Data
    let isValid: Bool

    override class var databaseTableName: String {
        return "masternodes"
    }

    enum Columns: String, ColumnExpression {
        case proRegTxHash
        case confirmedHash
        case confirmedHashWithProRegTxHash
        case ipAddress
        case port
        case pubKeyOperator
        case keyIDVoting
        case isValid
    }

    required init(row: Row) {
        proRegTxHash = row[Columns.proRegTxHash]
        confirmedHash = row[Columns.confirmedHash]
        confirmedHashWithProRegTxHash = row[Columns.confirmedHashWithProRegTxHash]
        ipAddress = row[Columns.ipAddress]
        port = row[Columns.port]
        pubKeyOperator = row[Columns.pubKeyOperator]
        keyIDVoting = row[Columns.keyIDVoting]
        isValid = row[Columns.isValid]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.proRegTxHash] = proRegTxHash
        container[Columns.confirmedHash] = confirmedHash
        container[Columns.confirmedHashWithProRegTxHash] = confirmedHashWithProRegTxHash
        container[Columns.ipAddress] = ipAddress
        container[Columns.port] = port
        container[Columns.pubKeyOperator] = pubKeyOperator
        container[Columns.keyIDVoting] = keyIDVoting
        container[Columns.isValid] = isValid
    }

    init(proRegTxHash: Data, confirmedHash: Data, confirmedHashWithProRegTxHash: Data, ipAddress: Data, port: UInt16, pubKeyOperator: Data, keyIDVoting: Data, isValid: Bool) {
        self.proRegTxHash = proRegTxHash
        self.confirmedHash = confirmedHash
        self.confirmedHashWithProRegTxHash = confirmedHashWithProRegTxHash
        self.ipAddress = ipAddress
        self.port = port
        self.pubKeyOperator = pubKeyOperator
        self.keyIDVoting = keyIDVoting
        self.isValid = isValid

        super.init()
    }

}

extension Masternode: Hashable, Comparable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(proRegTxHash)
    }

    public static func ==(lhs: Masternode, rhs: Masternode) -> Bool {
        return lhs.proRegTxHash == rhs.proRegTxHash
    }

    public static func <(lhs: Masternode, rhs: Masternode) -> Bool {
        return lhs.proRegTxHash < rhs.proRegTxHash
    }

}
