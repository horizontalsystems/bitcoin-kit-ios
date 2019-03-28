import RealmSwift

class UnspentOutputProvider {
    let realmFactory: IRealmFactory
    let confirmationsThreshold: Int

    init(realmFactory: IRealmFactory, confirmationsThreshold: Int) {
        self.realmFactory = realmFactory
        self.confirmationsThreshold = confirmationsThreshold
    }
}

extension UnspentOutputProvider: IUnspentOutputProvider {

    var allUnspentOutputs: [TransactionOutput] {
        let realm = realmFactory.realm
        let lastBlockHeight = realmFactory.realm.objects(Block.self).sorted(byKeyPath: "height").last?.height ?? 0

        let results = Array(realm.objects(TransactionOutput.self)
                .filter("publicKey != nil")
                .filter("scriptType != %@", ScriptType.unknown.rawValue)
                .filter("inputs.@count = %@", 0))

        return results.filter { (output: TransactionOutput) in
                guard let transaction = output.transaction else {
                    return false
                }
                return ((transaction.block?.height ?? lastBlockHeight) <= lastBlockHeight - confirmationsThreshold + 1)
        }
    }

    var balance: Int {
        var balance = 0

        for output in self.allUnspentOutputs {
            balance += output.value
        }

        return balance
    }

}