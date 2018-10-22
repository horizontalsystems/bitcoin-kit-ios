import Foundation
import RealmSwift

@objc enum ScriptType: Int {
    case unknown, p2pkh, p2pk, p2multi, p2sh, p2wsh, p2wpkh, p2wpkhSh

    var size: Int {
        switch self {
            case .p2pk: return 35
            case .p2pkh: return 25
            case .p2sh: return 23
            case .p2wsh: return 34
            case .p2wpkh: return 22
            default: return 0
        }
    }

    var keyLength: UInt8 {
        switch self {
            case .p2pk: return 0x21
            case .p2pkh: return 0x14
            case .p2sh: return 0x14
            case .p2wsh: return 0x20
            case .p2wpkh: return 0x14
            default: return 0
        }
    }

    var addressType: AddressType {
        switch self {
            case .p2sh, .p2wsh: return .scriptHash
            default: return .pubKeyHash
        }
    }

}

class TransactionOutput: Object {

    @objc dynamic var value: Int = 0
    @objc dynamic var lockingScript = Data()
    @objc dynamic var index: Int = 0

    @objc dynamic var publicKey: PublicKey?
    @objc dynamic var scriptType: ScriptType = .unknown
    @objc dynamic var keyHash: Data?
    @objc dynamic var address: String?

    let transactions = LinkingObjects(fromType: Transaction.self, property: "outputs")
    var transaction: Transaction? {
        return self.transactions.first
    }

    let inputs = LinkingObjects(fromType: TransactionInput.self, property: "previousOutput")

    convenience init(withValue value: Int, index: Int, lockingScript script: Data, type: ScriptType, address: String? = nil, keyHash: Data?, publicKey: PublicKey? = nil) {
        self.init()

        self.value = value
        self.lockingScript = script
        self.index = index
        self.scriptType = type
        self.address = address
        self.keyHash = keyHash
        self.publicKey = publicKey
    }

}
