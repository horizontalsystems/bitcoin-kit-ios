import HSHDWalletKit

class AddressManager {

    enum AddressManagerError: Error {
        case noUnusedPublicKey
    }

    private let storage: IStorage
    private let hdWallet: IHDWallet
    private let addressKeyHashConverter: IAddressKeyHashConverter?
    private let addressConverter: IAddressConverter

    init(storage: IStorage, hdWallet: IHDWallet, addressConverter: IAddressConverter, addressKeyHashConverter: IAddressKeyHashConverter? = nil) {
        self.storage = storage
        self.addressConverter = addressConverter
        self.addressKeyHashConverter = addressKeyHashConverter
        self.hdWallet = hdWallet
    }

    private func fillGap(publicKeysWithUsedStates: [PublicKeyWithUsedState], account: Int, external: Bool) throws {
        let publicKeys = publicKeysWithUsedStates.filter({ $0.publicKey.account == account && $0.publicKey.external == external })
        let gapKeysCount = self.gapKeysCount(publicKeyResults: publicKeys)
        var keys = [PublicKey]()

        if gapKeysCount < hdWallet.gapLimit {
            let allKeys = publicKeys.sorted(by: { $0.publicKey.index < $1.publicKey.index })
            let lastIndex = allKeys.last?.publicKey.index ?? -1

            for i in 1..<(hdWallet.gapLimit - gapKeysCount + 1) {
                let publicKey = try hdWallet.publicKey(account: account, index: lastIndex + i, external: external)
                keys.append(publicKey)
            }
        }

        try addKeys(keys: keys)
    }

    private func gapKeysCount(publicKeyResults publicKeysWithUsedStates: [PublicKeyWithUsedState]) -> Int {
        if let lastUsedKey = publicKeysWithUsedStates.filter({ $0.used }).sorted(by: { $0.publicKey.index < $1.publicKey.index }).last {
            return publicKeysWithUsedStates.filter({ $0.publicKey.index > lastUsedKey.publicKey.index }).count
        } else {
            return publicKeysWithUsedStates.count
        }
    }

    private func publicKey(external: Bool) throws -> PublicKey {
        guard let unusedKey = storage.publicKeysWithUsedState()
                .filter({ $0.publicKey.external == external && $0.publicKey.account == 0 && !$0.used })
                .sorted(by: { $0.publicKey.index < $1.publicKey.index })
                .first else {
            throw AddressManagerError.noUnusedPublicKey
        }

        return unusedKey.publicKey
    }
}

extension AddressManager: IAddressManager {

    func changePublicKey() throws -> PublicKey {
        return try publicKey(external: false)
    }

    func receiveAddress(for type: ScriptType) throws -> String {
        let keyHash = try publicKey(external: true).keyHash
        let correctKeyHash = addressKeyHashConverter?.convert(keyHash: keyHash, type: type) ?? keyHash

        return try addressConverter.convert(keyHash: correctKeyHash, type: type).stringValue
    }

    func fillGap() throws {
        let publicKeysWithUsedStates = storage.publicKeysWithUsedState()
        let requiredAccountsCount: Int

        if let lastUsedAccount = publicKeysWithUsedStates.filter({ $0.used }).sorted(by: { $0.publicKey.account < $1.publicKey.account }).last?.publicKey.account {
            requiredAccountsCount = lastUsedAccount + 1 + 1 // One because account starts from 0, One because we must have n+1 accounts
        } else {
            requiredAccountsCount = 1
        }

        for i in 0..<requiredAccountsCount {
            try fillGap(publicKeysWithUsedStates: publicKeysWithUsedStates, account: i, external: true)
            try fillGap(publicKeysWithUsedStates: publicKeysWithUsedStates, account: i, external: false)
        }
    }

    func addKeys(keys: [PublicKey]) throws {
        guard !keys.isEmpty else {
            return
        }

        storage.add(publicKeys: keys)
    }

    func gapShifts() -> Bool {
        let publicKeysWithUsedStates = storage.publicKeysWithUsedState()

        guard let lastAccount = publicKeysWithUsedStates.sorted(by: { $0.publicKey.account < $1.publicKey.account }).last?.publicKey.account else {
            return false
        }

        for i in 0..<(lastAccount + 1) {
            if gapKeysCount(publicKeyResults: publicKeysWithUsedStates.filter{ $0.publicKey.account == i && $0.publicKey.external }) < hdWallet.gapLimit {
                return true
            }

            if gapKeysCount(publicKeyResults: publicKeysWithUsedStates.filter{ $0.publicKey.account == i && !$0.publicKey.external }) < hdWallet.gapLimit {
                return true
            }
        }

        return false
    }

}

extension AddressManager {

    public static func instance(storage: IStorage, hdWallet: IHDWallet, addressConverter: IAddressConverter, addressKeyHashConverter: IAddressKeyHashConverter? = nil) -> AddressManager {
        let addressManager = AddressManager(storage: storage, hdWallet: hdWallet, addressConverter: addressConverter, addressKeyHashConverter: addressKeyHashConverter)
        try? addressManager.fillGap()
        return addressManager
    }

}
