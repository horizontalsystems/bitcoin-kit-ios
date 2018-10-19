import HSHDWalletKit

extension HDWallet: IHDWallet {

    func publicKey(index: Int, external: Bool) throws -> PublicKey {
        return PublicKey(withIndex: index, external: external, hdPublicKeyData: try publicKey(index: index, chain: external ? .external : .internal).raw)
    }

    func privateKeyData(index: Int, external: Bool) throws -> Data {
        return try privateKey(index: index, chain: external ? .external : .internal).raw
    }

}
