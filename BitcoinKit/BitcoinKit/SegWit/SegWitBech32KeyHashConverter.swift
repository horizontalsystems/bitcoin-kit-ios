import BitcoinCore
import HSCryptoKit

class SegWitBech32KeyHashConverter: IAddressKeyHashConverter {

    func convert(keyHash: Data, type: ScriptType) -> Data {
        switch type {
        case .p2wpkh: return OpCode.scriptWPKH(keyHash)
        case .p2wpkhSh:return CryptoKit.sha256ripemd160(OpCode.scriptWPKH(keyHash))
        default: return keyHash
        }
    }

}
