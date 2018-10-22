import HSHDWalletKit
import Realm
import RealmSwift

class AddressManager {

    enum AddressManagerError: Error {
        case noUnusedPublicKey
    }

    private let realmFactory: IRealmFactory
    private let hdWallet: IHDWallet
    private let addressConverter: IAddressConverter

    init(realmFactory: IRealmFactory, hdWallet: IHDWallet, addressConverter: IAddressConverter) {
        self.realmFactory = realmFactory
        self.addressConverter = addressConverter
        self.hdWallet = hdWallet
    }

    private func fillGap(external: Bool) throws {
        let realm = realmFactory.realm
        let publicKeys = realm.objects(PublicKey.self).filter("external = %@", external)
        let gapKeysCount = self.gapKeysCount(publicKeyResults: publicKeys)
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

    private func gapKeysCount(publicKeyResults publicKeys: Results<PublicKey>) -> Int {
        var gapKeysCount = 0

        if let lastUsedKey = publicKeys.filter("outputs.@count > 0").sorted(byKeyPath: "index").last {
            gapKeysCount = publicKeys.filter("index > %@", lastUsedKey.index).count
        } else {
            gapKeysCount = publicKeys.count
        }

        return gapKeysCount
    }

    private func publicKey(external: Bool) throws -> PublicKey {
        let realm = realmFactory.realm

        guard let unusedKey = realm.objects(PublicKey.self).filter("external = %@ AND outputs.@count = 0", external).sorted(byKeyPath: "index").first else {
            throw AddressManagerError.noUnusedPublicKey
        }

        return unusedKey
    }
}

extension AddressManager: IAddressManager {

    func changePublicKey() throws -> PublicKey {
        return try publicKey(external: false)
    }

    func receiveAddress() throws -> String {
        return try addressConverter.convert(keyHash: publicKey(external: true).keyHash, type: .p2pkh).stringValue
    }

    func fillGap() throws {
        try fillGap(external: true)
        try fillGap(external: false)
    }

    func addKeys(keys: [PublicKey]) throws {
        guard !keys.isEmpty else {
            return
        }

        let realm = realmFactory.realm
        try realm.write {
            realm.add(keys, update: true)
        }
    }

    func gapShifts() -> Bool {
        let realm = realmFactory.realm

        let externalPublicKeys = realm.objects(PublicKey.self).filter("external = %@", true)
        let internalPublicKeys = realm.objects(PublicKey.self).filter("external = %@", false)

        return gapKeysCount(publicKeyResults: externalPublicKeys) < hdWallet.gapLimit || gapKeysCount(publicKeyResults: internalPublicKeys) < hdWallet.gapLimit
    }

}
