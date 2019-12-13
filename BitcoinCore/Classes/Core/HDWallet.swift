import HdWalletKit

extension HDWallet: IHDWallet {

    func publicKey(account: Int, index: Int, external: Bool) throws -> PublicKey {
        return PublicKey(withAccount: account, index: index, external: external, hdPublicKeyData: try publicKey(account: account, index: index, chain: external ? .external : .internal).raw)
    }

    func privateKeyData(account: Int, index: Int, external: Bool) throws -> Data {
        return try privateKey(account: account, index: index, chain: external ? .external : .internal).raw
    }

}
