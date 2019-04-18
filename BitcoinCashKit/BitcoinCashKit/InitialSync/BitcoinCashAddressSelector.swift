import BitcoinCore

class BitcoinCashAddressSelector: IAddressSelector {

    func getAddressVariants(addressConverter: IAddressConverter, publicKey: PublicKey) -> [String] {
        let legacyAddress = (try? addressConverter.convert(keyHash: publicKey.keyHash, type: .p2pkh))?.stringValue
        return [legacyAddress].compactMap { $0 }
    }

}
