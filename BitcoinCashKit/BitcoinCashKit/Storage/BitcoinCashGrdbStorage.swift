import GRDB
import BitcoinCore

class BitcoinCashGrdbStorage: GrdbStorage {
}

extension BitcoinCashGrdbStorage: IBitcoinCashStorage {

    func timestamps(from startHeight: Int, to endHeight: Int, ascending: Bool) -> [Int] {
        return try! dbPool.read { db in
            var timestamps = [Int]()

            let sql = "SELECT blocks.timestamp FROM blocks WHERE blocks.height >= \(startHeight) AND blocks.height <= \(endHeight) ORDER BY blocks.timestamp \(ascending ? "ASC" : "DESC")"
            let rows = try Row.fetchCursor(db, sql: sql)

            while let row = try rows.next() {
                if let timestamp = Int.fromDatabaseValue(row["timestamp"]) {
                    timestamps.append(timestamp)
                }
            }

            return timestamps
        }
    }

}
