import Foundation
import RealmSwift

class TransactionPublicKeySetter {
}

extension TransactionPublicKeySetter: ITransactionPublicKeySetter {

    public func set(transaction: Transaction, realm: Realm) {
        let results = realm.objects(PublicKey.self)

        for output in transaction.outputs {
            if let key = output.keyHash {
                var correctKey = key
                if output.scriptType == .p2wpkh, key.count > 2 {
                    correctKey = key.dropFirst(2)
                }
                for result in results {
                    if result.raw == correctKey || result.keyHash == correctKey {
                        output.publicKey = result
                        transaction.isMine = true
                        break
                    }
                    if result.scriptHashForP2WPKH == correctKey {
                        output.publicKey = result
                        output.scriptType = .p2wpkhSh
                        transaction.isMine = true
                        break
                    }
                }
            }
        }
    }

}
