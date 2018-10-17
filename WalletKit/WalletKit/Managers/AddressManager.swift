import Foundation
import HSHDWalletKit
import Realm
import RealmSwift

class AddressManager {

    private let realmFactory: RealmFactory
    private let hdWallet: HDWallet
    private let addressConverter: AddressConverter
    private let bloomFilterManager: BloomFilterManager

    init(realmFactory: RealmFactory, hdWallet: HDWallet, bloomFilterManager: BloomFilterManager, addressConverter: AddressConverter) {
        self.realmFactory = realmFactory
        self.addressConverter = addressConverter
        self.hdWallet = hdWallet
        self.bloomFilterManager = bloomFilterManager
    }

    func changePublicKey() throws -> PublicKey {
        return try publicKey(chain: .internal)
    }

    func receiveAddress() throws -> String {
        return try addressConverter.convert(keyHash: publicKey(chain: .external).keyHash, type: .p2pkh).stringValue
    }

    func fillGap(afterExternalKey externalKey: PublicKey? = nil, afterInternalKey internalKey: PublicKey? = nil) throws {
        try fillGap(external: true, afterKey: externalKey)
        try fillGap(external: false, afterKey: internalKey)
    }

    func addKeys(keys: [PublicKey]) throws {
//        guard !keys.isEmpty else {
//            return
//        }

        let realm = realmFactory.realm
        try realm.write {
            realm.add(keys, update: true)
        }

        bloomFilterManager.regenerateBloomFilter()
    }

    func gapShifts() -> Bool {
        let realm = realmFactory.realm

        let externalPublicKeys = realm.objects(PublicKey.self).filter("external = %@", true)
        let internalPublicKeys = realm.objects(PublicKey.self).filter("external = %@", false)

        return gapKeysCount(publicKeyResults: externalPublicKeys) < hdWallet.gapLimit || gapKeysCount(publicKeyResults: internalPublicKeys) < hdWallet.gapLimit
    }

    private func fillGap(external: Bool, afterKey key: PublicKey?) throws {
        let realm = realmFactory.realm
        let publicKeys = realm.objects(PublicKey.self).filter("external = %@", external)
        let gapKeysCount = self.gapKeysCount(publicKeyResults: publicKeys, afterKey: key)
        var keys = [PublicKey]()
        if gapKeysCount < hdWallet.gapLimit {
            let allKeys = publicKeys.sorted(byKeyPath: "index")
            let lastIndex = allKeys.last?.index ?? -1

            for i in 1..<(hdWallet.gapLimit - gapKeysCount + 1) {
                let publicKey = try hdWallet.publicKey(index: lastIndex + i, external: external)
                keys.append(publicKey)
            }
        }

        try addKeys(keys: keys)
    }

    private func gapKeysCount(publicKeyResults publicKeys: Results<PublicKey>, afterKey key: PublicKey? = nil) -> Int {
        var gapKeysCount = 0

        if var lastUsedKey = publicKeys.filter("outputs.@count > 0").sorted(byKeyPath: "index").last {
            if let key = key, lastUsedKey.index < key.index {
                lastUsedKey = key
            }
            gapKeysCount = publicKeys.filter("index > %@", lastUsedKey.index).count
        } else {
            gapKeysCount = publicKeys.count
        }

        return gapKeysCount
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
        bloomFilterManager.regenerateBloomFilter()

        return newKey
    }

}
