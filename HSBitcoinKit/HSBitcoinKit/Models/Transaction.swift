import Foundation
import HSCryptoKit
import RealmSwift

@objc enum TransactionStatus: Int { case new, relayed, invalid }

class Transaction: Object {
    @objc dynamic var reversedHashHex: String = ""
    @objc dynamic var dataHash = Data()
    @objc dynamic var version: Int = 0
    @objc dynamic var lockTime: Int = 0
    @objc dynamic var block: Block?

    @objc dynamic var isMine: Bool = false
    @objc dynamic var isOutgoing: Bool = false
    @objc dynamic var status: TransactionStatus = .relayed

    @objc dynamic var segWit: Bool = false

    let inputs = List<TransactionInput>()
    let outputs = List<TransactionOutput>()

    override class func primaryKey() -> String? {
        return "reversedHashHex"
    }

    convenience init(version: Int, inputs: [TransactionInput], outputs: [TransactionOutput], lockTime: Int = 0) {
        self.init()

        self.version = version

        inputs.forEach { self.inputs.append($0) }
        outputs.forEach { self.outputs.append($0) }

        self.lockTime = lockTime
        dataHash = CryptoKit.sha256sha256(TransactionSerializer.serialize(transaction: self, withoutWitness: true))
        reversedHashHex = dataHash.reversedHex
    }

}

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
