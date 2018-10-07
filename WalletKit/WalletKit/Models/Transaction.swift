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

    @objc dynamic var processed: Bool = false
    @objc dynamic var isMine: Bool = false
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
        dataHash = CryptoKit.sha256sha256(TransactionSerializer.serialize(transaction: self))
        reversedHashHex = dataHash.reversedHex
    }

}
