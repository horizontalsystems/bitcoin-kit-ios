import Foundation
import HSCryptoKit
import HSHDWalletKit
import RealmSwift

class PublicKey: Object {

    enum InitError: Error {
        case invalid
        case wrongNetwork
    }

    let outputs = LinkingObjects(fromType: TransactionOutput.self, property: "publicKey")

    @objc dynamic var index = 0
    @objc dynamic var external = true
    @objc dynamic var raw: Data?
    @objc dynamic var keyHash = Data()
    @objc dynamic var scriptHashForP2WPKH = Data()
    @objc dynamic var keyHashHex: String = ""

    convenience init(withIndex index: Int, external: Bool, hdPublicKey key: HDPublicKey) {
        self.init()
        self.index = index
        self.external = external
        raw = key.raw
        keyHash = CryptoKit.sha256ripemd160(key.raw)

        let versionByte = 0
        let redeemScript = OpCode.push(versionByte) + OpCode.push(keyHash)
        scriptHashForP2WPKH = CryptoKit.sha256ripemd160(redeemScript)

        keyHashHex = keyHash.hex
    }

    override class func primaryKey() -> String? {
        return "keyHashHex"
    }

}
