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
    @objc dynamic var keyHashHex: String = ""

    convenience init(withIndex index: Int, external: Bool, hdPublicKey key: HDPublicKey) {
        self.init()
        self.index = index
        self.external = external
        self.raw = key.raw
        self.keyHash = CryptoKit.sha256ripemd160(key.raw)
        self.keyHashHex = keyHash.hex
    }

    override class func primaryKey() -> String? {
        return "keyHashHex"
    }

}

extension HDWallet {

    func publicKey(index: Int, external: Bool) throws -> PublicKey {
        return PublicKey(withIndex: index, external: external, hdPublicKey: try publicKey(index: index, chain: external ? .external : .internal))
    }

    func receivePublicKey(index: Int) throws -> PublicKey {
        return PublicKey(withIndex: index, external: true, hdPublicKey: try publicKey(index: index, chain: .external))
    }

    func changePublicKey(index: Int) throws -> PublicKey {
        return PublicKey(withIndex: index, external: false, hdPublicKey: try publicKey(index: index, chain: .internal))
    }

}
