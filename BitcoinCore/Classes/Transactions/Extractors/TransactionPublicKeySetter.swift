import Foundation

class TransactionPublicKeySetter {
    let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }
}

extension TransactionPublicKeySetter: ITransactionPublicKeySetter {

    public func set(output: Output) {
        if let key = output.keyHash {
            var correctKey = key
            if output.scriptType == .p2wpkh, key.count > 2 {
                correctKey = key.dropFirst(2)
            }
            if output.scriptType == .p2sh {
                if let publicKey = storage.publicKey(byScriptHashForP2WPKH: correctKey) {
                    output.set(publicKey: publicKey)
                    output.keyHash = publicKey.keyHash
                    output.scriptType = .p2wpkhSh
                    return
                }
            }
            if let publicKey = storage.publicKey(byRawOrKeyHash: correctKey) {
                output.set(publicKey: publicKey)
                return
            }
        }
    }

}
