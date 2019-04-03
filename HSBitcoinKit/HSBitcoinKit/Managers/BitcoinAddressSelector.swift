import Foundation

class BitcoinAddressSelector: IAddressSelector {

    func getAddressVariants(addressConverter: IAddressConverter, publicKey: PublicKey) -> [String] {
        let wpkhShAddress = try? addressConverter.convert(keyHash: publicKey.scriptHashForP2WPKH, type: .p2sh).stringValue
        return [wpkhShAddress, publicKey.keyHashHex].compactMap { $0 }
    }

}
