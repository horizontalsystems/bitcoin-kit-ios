import Realm
import RealmSwift
import Foundation

class AddressManager {

    private let realmFactory: RealmFactory
    private let hdWallet: HDWallet
    private let peerGroup: PeerGroup

    init(realmFactory: RealmFactory, hdWallet: HDWallet, peerGroup: PeerGroup) {
        self.realmFactory = realmFactory
        self.hdWallet = hdWallet
        self.peerGroup = peerGroup
    }

    func changePublicKey() throws -> PublicKey {
        return try getPublicKey(chain: .internal)
    }

    func receiveAddress() throws -> String {
        return try getPublicKey(chain: .external).address
    }

    func generateKeys() throws {
        let realm = realmFactory.realm
        let externalKeys = try generateKeys(external: true, realm: realm)
        let internalKeys = try generateKeys(external: false, realm: realm)

        try realm.write {
            realm.add(externalKeys)
            realm.add(internalKeys)
        }

        for pubKey in externalKeys {
            peerGroup.addPublicKeyFilter(pubKey: pubKey)
        }

        for pubKey in internalKeys {
            peerGroup.addPublicKeyFilter(pubKey: pubKey)
        }
    }

    private func generateKeys(external: Bool, realm: Realm) throws -> [PublicKey] {
        var keys = [PublicKey]()
        let allKeys = realm.objects(PublicKey.self).filter("external = %@", external).sorted(byKeyPath: "index")
        let unusedKeysCount = realm.objects(PublicKey.self).filter("external = %@ AND outputs.@count = 0", external).sorted(byKeyPath: "index").count

        if unusedKeysCount < hdWallet.gapLimit {
            let lastIndex = allKeys.last?.index ?? -1

            for i in 1..<(hdWallet.gapLimit - unusedKeysCount + 1) {
                let newPublicKey = try external ? hdWallet.receivePublicKey(index: lastIndex + i) : hdWallet.changePublicKey(index: lastIndex + i)
                keys.append(newPublicKey)
            }
        }

        return keys
    }

    private func getPublicKey(chain: HDWallet.Chain) throws -> PublicKey {
        let realm = realmFactory.realm

        if let unusedKey = realm.objects(PublicKey.self).filter("external = %@ AND outputs.@count = 0", chain == .external).sorted(byKeyPath: "index").first {
            return unusedKey
        }

        let existingKeys = realm.objects(PublicKey.self).filter("external = %@", chain == .external).sorted(byKeyPath: "index")
        let newIndex = (existingKeys.last?.index ?? -1) + 1
        let newPublicKey = try chain == .external ? hdWallet.receivePublicKey(index: newIndex) : hdWallet.changePublicKey(index: newIndex)

        try realm.write {
            realm.add(newPublicKey)
        }

        peerGroup.addPublicKeyFilter(pubKey: newPublicKey)

        return newPublicKey
    }

}
