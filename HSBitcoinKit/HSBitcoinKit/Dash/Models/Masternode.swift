import GRDB

class Masternode: Record {
    let proRegTxHash: Data
    let confirmedHash: Data
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
        case ipAddress
        case port
        case pubKeyOperator
        case keyIDVoting
        case isValid
    }

    required init(row: Row) {
        proRegTxHash = row[Columns.proRegTxHash]
        confirmedHash = row[Columns.confirmedHash]
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
        container[Columns.ipAddress] = ipAddress
        container[Columns.port] = port
        container[Columns.pubKeyOperator] = pubKeyOperator
        container[Columns.keyIDVoting] = keyIDVoting
        container[Columns.isValid] = isValid
    }

    init(byteStream: ByteStream) {
        proRegTxHash = byteStream.read(Data.self, count: 32)
        confirmedHash = byteStream.read(Data.self, count: 32)
        ipAddress = byteStream.read(Data.self, count: 16)
        port = byteStream.read(UInt16.self)
        pubKeyOperator = byteStream.read(Data.self, count: 48)
        keyIDVoting = byteStream.read(Data.self, count: 20)
        isValid = byteStream.read(UInt8.self) != 0

        super.init()
    }

    init(proRegTxHash: Data, confirmedHash: Data, ipAddress: Data, port: UInt16, pubKeyOperator: Data, keyIDVoting: Data, isValid: Bool) {
        self.proRegTxHash = proRegTxHash
        self.confirmedHash = confirmedHash
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
        guard lhs.proRegTxHash.count == lhs.proRegTxHash.count else {
            return lhs.proRegTxHash.count < rhs.proRegTxHash.count
        }

        let count = lhs.proRegTxHash.count
        for index in 0..<count {
            if lhs.proRegTxHash[index] == rhs.proRegTxHash[index] {
                continue
            } else {
                return lhs.proRegTxHash[index] < rhs.proRegTxHash[index]
            }
        }
        return true
    }
}
