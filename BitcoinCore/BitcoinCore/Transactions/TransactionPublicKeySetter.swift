import Foundation

class TransactionPublicKeySetter {
    let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }
}

extension TransactionPublicKeySetter: ITransactionPublicKeySetter {

    public func set(output: Output) -> Bool {
        if let key = output.keyHash {
            var correctKey = key
            if output.scriptType == .p2wpkh, key.count > 2 {
                correctKey = key.dropFirst(2)
                if let publicKey = storage.publicKey(byScriptHashForP2WPKH: correctKey) {
                    output.publicKeyPath = publicKey.path
                    output.scriptType = .p2wpkhSh
                    return true
                }
            }
            if let publicKey = storage.publicKey(byRawOrKeyHash: correctKey) {
                output.publicKeyPath = publicKey.path
                return true
            }
        }
        return false
    }

}
