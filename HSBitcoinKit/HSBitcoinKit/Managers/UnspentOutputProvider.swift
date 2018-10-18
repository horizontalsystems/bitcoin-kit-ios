class UnspentOutputProvider {
    let realmFactory: IRealmFactory

    init(realmFactory: IRealmFactory) {
        self.realmFactory = realmFactory
    }
}

extension UnspentOutputProvider: IUnspentOutputProvider {

    func allUnspentOutputs() -> [TransactionOutput] {
        let realm = realmFactory.realm
        let allUnspentOutputs = realm.objects(TransactionOutput.self)
                .filter("publicKey != nil")
                .filter("scriptType != %@", ScriptType.unknown.rawValue)
                .filter("inputs.@count = %@", 0)

        return Array(allUnspentOutputs)
    }

}
