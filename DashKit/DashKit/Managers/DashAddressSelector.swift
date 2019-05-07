import BitcoinCore

public class DashAddressSelector: IAddressSelector {

    public init() {}

    public func getAddressVariants(addressConverter: IAddressConverter, publicKey: PublicKey) -> [String] {
        let address = try? addressConverter.convert(keyHash: publicKey.keyHash, type: .p2pkh).stringValue
        return [address].compactMap { $0 }
    }

}
