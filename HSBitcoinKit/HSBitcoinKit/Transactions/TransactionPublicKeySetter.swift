import Foundation
import RealmSwift

class TransactionPublicKeySetter {
    let realmFactory: IRealmFactory

    init(realmFactory: IRealmFactory) {
        self.realmFactory = realmFactory
    }
}

extension TransactionPublicKeySetter: ITransactionPublicKeySetter {

    public func set(output: TransactionOutput) -> Bool {
        let realm = realmFactory.realm

        if let key = output.keyHash {
            var correctKey = key
            if output.scriptType == .p2wpkh, key.count > 2 {
                correctKey = key.dropFirst(2)
                if let result = realm.objects(PublicKey.self).filter("scriptHashForP2WPKH = %@", correctKey).first {
                    output.publicKey = result
                    output.scriptType = .p2wpkhSh
                    return true
                }
            }
            if let result = realm.objects(PublicKey.self).filter("raw = %@ OR keyHash = %@", correctKey, correctKey).first {
                output.publicKey = result
                return true
            }
        }
        return false
    }

}
