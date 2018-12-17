import Foundation
import HSCryptoKit

class TransactionOutputAddressExtractor {
    private let addressConverter: IAddressConverter

    init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

}

extension TransactionOutputAddressExtractor: ITransactionOutputAddressExtractor {

    public func extractOutputAddresses(transaction: Transaction) {
        for output in transaction.outputs {
            guard let key = output.keyHash else {
                continue
            }
            let keyHash: Data

            switch output.scriptType {
            case .p2pk: keyHash = output.publicKey?.keyHash ?? CryptoKit.sha256ripemd160(key)
            default: keyHash = key
            }

            let scriptType = output.scriptType
            if let address = try? addressConverter.convert(keyHash: keyHash, type: scriptType) {
                output.address = address.stringValue
            }
        }
    }

}
