import Foundation

extension Array where Element == Transaction {

    func inTopologicalOrder() -> [Transaction] {
        var ordered = [Transaction]()

        var visited = [Bool](repeating: false, count: self.count)

        for i in 0..<self.count {
            visit(transactionWithIndex: i, picked: &ordered, visited: &visited)
        }

        return ordered
    }

    private func visit(transactionWithIndex transactionIndex: Int, picked: inout [Transaction], visited: inout [Bool]) {
        guard !picked.contains(where: { self[transactionIndex].reversedHashHex == $0.reversedHashHex }) else {
            return
        }

        guard !visited[transactionIndex] else {
            return
        }

        visited[transactionIndex] = true

        for candidateTransactionIndex in 0..<self.count {
            for input in self[transactionIndex].inputs {
                if input.previousOutputTxReversedHex == self[candidateTransactionIndex].reversedHashHex,
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
