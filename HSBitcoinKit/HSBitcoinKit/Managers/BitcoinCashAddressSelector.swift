import Foundation

class BitcoinCashAddressSelector: IAddressSelector {
    private let addressConverter: IAddressConverter

    init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

    func getAddressVariants(publicKey: PublicKey) -> [String] {
        let legacyAddress = (try? addressConverter.convert(keyHash: publicKey.keyHash, type: .p2pkh))?.stringValue
        return [legacyAddress].compactMap { $0 }
    }

}
