import Foundation

class UnspentOutputProvider {

    let realmFactory: RealmFactory

    init(realmFactory: RealmFactory) {
        self.realmFactory = realmFactory
    }

    func allUnspentOutputs() -> [TransactionOutput] {
        let realm = realmFactory.realm
        let allUnspentOutputs = realm.objects(TransactionOutput.self)
                .filter("publicKey != nil")
                .filter("scriptType != %@", ScriptType.unknown.rawValue)
                .filter("inputs.@count = %@", 0)

        return Array(allUnspentOutputs)
    }

}
