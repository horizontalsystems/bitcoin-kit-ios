import HdWalletKit

class PublicKeyManager {

    enum PublicKeyManagerError: Error {
        case noUnusedPublicKey
        case invalidPath
    }

    private let restoreKeyConverter: IRestoreKeyConverter
    private let storage: IStorage
    private let hdWallet: IHDWallet
    weak var bloomFilterManager: IBloomFilterManager?

    init(storage: IStorage, hdWallet: IHDWallet, restoreKeyConverter: IRestoreKeyConverter) {
        self.storage = storage
        self.hdWallet = hdWallet
        self.restoreKeyConverter = restoreKeyConverter
    }

    private func fillGap(publicKeysWithUsedStates: [PublicKeyWithUsedState], account: Int, external: Bool) throws {
        let publicKeys = publicKeysWithUsedStates.filter({ $0.publicKey.account == account && $0.publicKey.external == external })
        let gapKeysCount = self.gapKeysCount(publicKeyResults: publicKeys)
        var keys = [PublicKey]()

        if gapKeysCount < hdWallet.gapLimit {
            let allKeys = publicKeys.sorted(by: { $0.publicKey.index < $1.publicKey.index })
            let lastIndex = allKeys.last?.publicKey.index ?? -1
            let newKeysStartIndex = lastIndex + 1
            let indices = UInt32(newKeysStartIndex)..<UInt32(newKeysStartIndex + hdWallet.gapLimit - gapKeysCount)

            keys = try hdWallet.publicKeys(account: account, indices: indices, external: external)
        }

        addKeys(keys: keys)
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
            throw PublicKeyManagerError.noUnusedPublicKey
        }

        return unusedKey.publicKey
    }
}

extension PublicKeyManager: IPublicKeyManager {

    func changePublicKey() throws -> PublicKey {
        return try publicKey(external: false)
    }

    func receivePublicKey() throws -> PublicKey {
        return try publicKey(external: true)
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

        bloomFilterManager?.regenerateBloomFilter()
    }

    func addKeys(keys: [PublicKey]) {
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

    public func publicKey(byPath path: String) throws -> PublicKey {
        let parts = path.split(separator: "/")

        guard parts.count == 3, let account = Int(parts[0]), let external = Int(parts[1]), let index = Int(parts[2]) else {
            throw PublicKeyManagerError.invalidPath
        }

        if let publicKey = storage.publicKey(byPath: path) {
            return publicKey
        }

        return try hdWallet.publicKey(account: account, index: index, external: external == 1)
    }
}

extension PublicKeyManager: IBloomFilterProvider {

    func filterElements() -> [Data] {
        var elements = [Data]()

        for publicKey in storage.publicKeys() {
            elements.append(contentsOf: restoreKeyConverter.bloomFilterElements(publicKey: publicKey))
        }

        return elements
    }

}

extension PublicKeyManager {

    public static func instance(storage: IStorage, hdWallet: IHDWallet, restoreKeyConverter: IRestoreKeyConverter) -> PublicKeyManager {
        let addressManager = PublicKeyManager(storage: storage, hdWallet: hdWallet, restoreKeyConverter: restoreKeyConverter)
        try? addressManager.fillGap()
        return addressManager
    }

}
