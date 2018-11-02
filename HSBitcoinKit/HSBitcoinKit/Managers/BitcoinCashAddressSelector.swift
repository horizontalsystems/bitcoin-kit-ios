import Foundation

class BitcoinCashAddressSelector: IAddressSelector {
    private let addressConverter: IAddressConverter

    init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

    func getAddressVariants(publicKey: PublicKey) -> [String] {
        let legacyAddress = (try? addressConverter.convertToLegacy(keyHash: publicKey.keyHash, version: 0, addressType: .pubKeyHash))?.stringValue
        return [legacyAddress].compactMap { $0 }
    }

}
