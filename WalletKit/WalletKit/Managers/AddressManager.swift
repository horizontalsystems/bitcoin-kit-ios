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
        return try publicKey(chain: .internal)
    }

    func receiveAddress() throws -> String {
        return try publicKey(chain: .external).address
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

        if unusedKeysCount < hdWallet.gapLimit {
            let allKeys = publicKeys.sorted(byKeyPath: "index")
            let lastIndex = allKeys.last?.index ?? -1

            for i in 1..<(hdWallet.gapLimit - unusedKeysCount + 1) {
                let _ = try publicKey(index: lastIndex + i, external: external)
            }
        }
    }

    func publicKey(index: Int, external: Bool) throws -> PublicKey {
        let realm = realmFactory.realm
        if let key = realm.objects(PublicKey.self).filter("external = %@ AND index = %@", external, index).last {
            return key
        }

        let publicKey = try hdWallet.publicKey(index: index, external: external)
        try realm.write {
            realm.add(publicKey)
        }

        peerGroup.addPublicKeyFilter(pubKey: publicKey)

        return  publicKey
    }

    private func publicKey(chain: HDWallet.Chain) throws -> PublicKey {
        let realm = realmFactory.realm

        if let unusedKey = realm.objects(PublicKey.self).filter("external = %@ AND outputs.@count = 0", chain == .external).sorted(byKeyPath: "index").first {
            return unusedKey
        }

        let existingKeys = realm.objects(PublicKey.self).filter("external = %@", chain == .external).sorted(byKeyPath: "index")
        let lastIndex = existingKeys.last?.index ?? -1

        return try publicKey(index: lastIndex + 1, external: chain == .external)
    }

}
