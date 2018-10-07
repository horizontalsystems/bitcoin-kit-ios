import Foundation
import HSHDWalletKit
import Realm
import RealmSwift

class AddressManager {

    private let realmFactory: RealmFactory
    private let hdWallet: HDWallet
    private let addressConverter: AddressConverter
    private let peerGroup: PeerGroup

    init(realmFactory: RealmFactory, hdWallet: HDWallet, peerGroup: PeerGroup, addressConverter: AddressConverter) {
        self.realmFactory = realmFactory
        self.addressConverter = addressConverter
        self.hdWallet = hdWallet
        self.peerGroup = peerGroup
    }

    func changePublicKey() throws -> PublicKey {
        return try publicKey(chain: .internal)
    }

    func receiveAddress() throws -> String {
        return try addressConverter.convert(keyHash: publicKey(chain: .external).keyHash, type: .p2pkh).stringValue
    }

    func generateKeys() throws {
        try generateKeys(external: true)
        try generateKeys(external: false)
    }

    private func generateKeys(external: Bool) throws {
        let realm = realmFactory.realm
        let publicKeys = realm.objects(PublicKey.self).filter("external = %@", external)
        var unusedKeysCount = 0

        if let lastUsedKey = publicKeys.filter("outputs.@count > 0").sorted(byKeyPath: "index").last {
            unusedKeysCount = publicKeys.filter("index > %@", lastUsedKey.index).count
        } else {
            unusedKeysCount = publicKeys.count
        }

        var keys = [PublicKey]()
        if unusedKeysCount < hdWallet.gapLimit {
            let allKeys = publicKeys.sorted(byKeyPath: "index")
            let lastIndex = allKeys.last?.index ?? -1

            for i in 1..<(hdWallet.gapLimit - unusedKeysCount + 1) {
                let publicKey = try hdWallet.publicKey(index: lastIndex + i, external: external)
                keys.append(publicKey)
            }
        }

        try addKeys(keys: keys)
    }

    func addKeys(keys: [PublicKey]) throws {
        let realm = realmFactory.realm

        try realm.write {
            realm.add(keys, update: true)
        }

        for key in keys {
            peerGroup.addPublicKeyFilter(pubKey: key)
        }
    }

    private func publicKey(chain: HDWallet.Chain) throws -> PublicKey {
        let realm = realmFactory.realm

        if let unusedKey = realm.objects(PublicKey.self).filter("external = %@ AND outputs.@count = 0", chain == .external).sorted(byKeyPath: "index").first {
            return unusedKey
        }

        let existingKeys = realm.objects(PublicKey.self).filter("external = %@", chain == .external).sorted(byKeyPath: "index")
        let lastIndex = existingKeys.last?.index ?? -1
        let newKey = try hdWallet.publicKey(index: lastIndex + 1, external: chain == .external)

        try realm.write {
            realm.add(newKey)
        }
        peerGroup.addPublicKeyFilter(pubKey: newKey)

        return newKey
    }

}
