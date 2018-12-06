import Foundation

class BitcoinAddressSelector: IAddressSelector {
    private let addressConverter: IAddressConverter

    init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

    func getAddressVariants(publicKey: PublicKey) -> [String] {
        let wpkhShAddress = try? addressConverter.convert(keyHash: publicKey.scriptHashForP2WPKH, type: .p2sh).stringValue
        return [wpkhShAddress, publicKey.keyHashHex].compactMap { $0 }
    }

}
