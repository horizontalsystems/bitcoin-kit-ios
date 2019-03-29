import HSHDWalletKit

class AddressManager {

    enum AddressManagerError: Error {
        case noUnusedPublicKey
    }

    private let storage: IStorage
    private let hdWallet: IHDWallet
    private let addressConverter: IAddressConverter

    init(storage: IStorage, hdWallet: IHDWallet, addressConverter: IAddressConverter) {
        self.storage = storage
        self.addressConverter = addressConverter
        self.hdWallet = hdWallet
    }

    private func fillGap(account: Int, external: Bool) throws {
        let publicKeys = storage.publicKeys().filter({ $0.account == account && $0.external == external })
        let gapKeysCount = self.gapKeysCount(publicKeyResults: publicKeys)
        var keys = [PublicKey]()

        if gapKeysCount < hdWallet.gapLimit {
            let allKeys = publicKeys.sorted(by: { $0.index < $1.index })
            let lastIndex = allKeys.last?.index ?? -1

            for i in 1..<(hdWallet.gapLimit - gapKeysCount + 1) {
                let publicKey = try hdWallet.publicKey(account: account, index: lastIndex + i, external: external)
                keys.append(publicKey)
            }
        }

        try addKeys(keys: keys)
    }

    private func gapKeysCount(publicKeyResults publicKeys: [PublicKey]) -> Int {
        if let lastUsedKey = publicKeys.filter({ $0.used(storage: self.storage) }).sorted(by: { $0.index < $1.index }).last {
            return publicKeys.filter({ $0.index > lastUsedKey.index }).count
        } else {
            return publicKeys.count
        }
    }

    private func publicKey(external: Bool) throws -> PublicKey {
        guard let unusedKey = storage.publicKeys()
                .filter({ $0.external == external && !$0.used(storage: self.storage) })
                .sorted(by: { $0.account < $1.account || ( $0.account == $1.account && $0.index < $1.index ) })
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

        if let lastUsedAccount = storage.publicKeys().filter({ $0.used(storage: storage) }).sorted(by: { $0.account < $1.account }).last?.account {
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

        storage.add(publicKeys: keys)
    }

    func gapShifts() -> Bool {
        guard let lastAccount = storage.publicKeys().sorted(by: { $0.account < $1.account }).last?.account else {
            return false
        }

        let publicKeys = storage.publicKeys()

        for i in 0..<(lastAccount + 1) {
            if gapKeysCount(publicKeyResults: publicKeys.filter{ $0.account == i && $0.external }) < hdWallet.gapLimit {
                return true
            }

            if gapKeysCount(publicKeyResults: publicKeys.filter{ $0.account == i && !$0.external }) < hdWallet.gapLimit {
                return true
            }
        }

        return false
    }

}

extension AddressManager {

    public static func instance(storage: IStorage, hdWallet: IHDWallet, addressConverter: IAddressConverter) -> AddressManager {
        let addressManager = AddressManager(storage: storage, hdWallet: hdWallet, addressConverter: addressConverter)
        try? addressManager.fillGap()
        return addressManager
    }

}
