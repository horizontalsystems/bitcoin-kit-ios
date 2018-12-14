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

    private func fillGap(account: Int, external: Bool) throws {
        let realm = realmFactory.realm
        let publicKeys = realm.objects(PublicKey.self).filter("account = %@ AND external = %@", account, external)
        let gapKeysCount = self.gapKeysCount(publicKeyResults: publicKeys)
        var keys = [PublicKey]()

        if gapKeysCount < hdWallet.gapLimit {
            let allKeys = publicKeys.sorted(byKeyPath: "index")
            let lastIndex = allKeys.last?.index ?? -1

            for i in 1..<(hdWallet.gapLimit - gapKeysCount + 1) {
                let publicKey = try hdWallet.publicKey(account: account, index: lastIndex + i, external: external)
                keys.append(publicKey)
            }
        }

        try addKeys(keys: keys)
    }

    private func gapKeysCount(publicKeyResults publicKeys: Results<PublicKey>) -> Int {
        if let lastUsedKey = publicKeys.filter("outputs.@count > 0").sorted(byKeyPath: "index").last {
            return publicKeys.filter("index > %@", lastUsedKey.index).count
        } else {
            return publicKeys.count
        }
    }

    private func publicKey(external: Bool) throws -> PublicKey {
        let realm = realmFactory.realm

        guard let unusedKey = realm.objects(PublicKey.self)
                .filter("external = %@ AND outputs.@count = 0", external)
                .sorted(by: [SortDescriptor(keyPath: "account"), SortDescriptor(keyPath: "index")])
                .first else {
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
        let requiredAccountsCount: Int!

        if let lastUsedAccount = realmFactory.realm.objects(PublicKey.self).filter("outputs.@count > 0").sorted(byKeyPath: "account").last?.account {
            requiredAccountsCount = lastUsedAccount + 1 + 1 // One because account starts from 0, One because we must have n+1 accounts
        } else {
            requiredAccountsCount = 1
        }

        for i in 0..<requiredAccountsCount {
            try fillGap(account: i, external: true)
            try fillGap(account: i, external: false)
        }
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
        guard let lastAccount = realmFactory.realm.objects(PublicKey.self).sorted(byKeyPath: "account").last?.account else {
            return false
        }

        let publicKeys = realmFactory.realm.objects(PublicKey.self)

        for i in 0..<(lastAccount + 1) {
            if gapKeysCount(publicKeyResults: publicKeys.filter("account = %@ AND external = %@", i, true)) < hdWallet.gapLimit {
                return true
            }

            if gapKeysCount(publicKeyResults: publicKeys.filter("account = %@ AND external = %@", i, false)) < hdWallet.gapLimit {
                return true
            }
        }

        return false
    }

}
