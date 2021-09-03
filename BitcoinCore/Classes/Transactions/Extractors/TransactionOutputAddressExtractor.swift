import Foundation
import OpenSslKit

class TransactionOutputAddressExtractor {
    private let storage: IStorage
    private let addressConverter: IAddressConverter

    init(storage: IStorage, addressConverter: IAddressConverter) {
        self.storage = storage
        self.addressConverter = addressConverter
    }

}

extension TransactionOutputAddressExtractor: ITransactionExtractor {

    public func extract(transaction: FullTransaction) {
        for output in transaction.outputs {
            guard let key = output.keyHash else {
                continue
            }
            let keyHash: Data

            switch output.scriptType {
            case .p2pk:
                keyHash = Kit.sha256ripemd160(key)
            case .p2wpkhSh:
                keyHash = Kit.sha256ripemd160(OpCode.scriptWPKH(key))
            default: keyHash = key
            }

            let scriptType = output.scriptType
            if let address = try? addressConverter.convert(keyHash: keyHash, type: scriptType) {
                output.address = address.stringValue
            }
        }
    }

}
