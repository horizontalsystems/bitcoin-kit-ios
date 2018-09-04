import Foundation
import RealmSwift

@objc enum TransactionStatus: Int { case new, relayed, invalid }

public class Transaction: Object {
    @objc public dynamic var reversedHashHex: String = ""
    @objc dynamic var version: Int = 0
    @objc dynamic var lockTime: Int = 0
    @objc public dynamic var block: Block?

    @objc dynamic var processed: Bool = false
    @objc dynamic var isMine: Bool = false
    @objc dynamic var status: TransactionStatus = .relayed

    public let inputs = List<TransactionInput>()
    public let outputs = List<TransactionOutput>()

    override public class func primaryKey() -> String? {
        return "reversedHashHex"
    }

    convenience init(version: Int, inputs: [TransactionInput], outputs: [TransactionOutput], lockTime: Int = 0) {
        self.init()

        self.version = version

        inputs.forEach { self.inputs.append($0) }
        outputs.forEach { self.outputs.append($0) }

        self.lockTime = lockTime
        reversedHashHex = Crypto.sha256sha256(TransactionSerializer.serialize(transaction: self)).reversedHex
    }

}
