import Foundation
import GRDB

extension Array where Element == FullTransaction {

    func inTopologicalOrder() -> [FullTransaction] {
        var ordered = [FullTransaction]()

        var visited = [Bool](repeating: false, count: self.count)

        for i in 0..<self.count {
            visit(transactionWithIndex: i, picked: &ordered, visited: &visited)
        }

        return ordered
    }

    private func visit(transactionWithIndex transactionIndex: Int, picked: inout [FullTransaction], visited: inout [Bool]) {
        guard !picked.contains(where: { self[transactionIndex].header.dataHash == $0.header.dataHash }) else {
            return
        }

        guard !visited[transactionIndex] else {
            return
        }

        visited[transactionIndex] = true

        for candidateTransactionIndex in 0..<self.count {
            for input in self[transactionIndex].inputs {
                if input.previousOutputTxHash == self[candidateTransactionIndex].header.dataHash,
                   self[candidateTransactionIndex].outputs.count > input.previousOutputIndex {
                    visit(transactionWithIndex: candidateTransactionIndex, picked: &picked, visited: &visited)
                }
            }
        }

        visited[transactionIndex] = false
        picked.append(self[transactionIndex])
    }

}

extension Array where Element : Hashable {

    var unique: [Element] {
        return Array(Set(self))
    }

}

extension Array: SQLExpressible where Element == Data {

    public var sqlExpression: SQLExpression {
        databaseValue.sqlExpression
    }

}

extension Array: DatabaseValueConvertible, StatementBinding where Element == Data {

    public var databaseValue: DatabaseValue {
        DataListSerializer.serialize(dataList: self).databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Array<Element>? {
        if case let DatabaseValue.Storage.blob(value) = dbValue.storage {
            return DataListSerializer.deserialize(data: value)
        }

        return nil
    }

}

extension Array {

    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

}
