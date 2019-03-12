import RealmSwift

class RealmFactory {
    private let configuration: Realm.Configuration

    init(realmFileName: String) {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        configuration = Realm.Configuration(
                fileURL: documentsUrl?.appendingPathComponent(realmFileName),
                schemaVersion: 2,
                deleteRealmIfMigrationNeeded: true,
                objectTypes: [
                    Block.self,
                    BlockHeader.self,
                    PublicKey.self,
                    Transaction.self,
                    TransactionInput.self,
                    TransactionOutput.self
                ]
        )
    }

}

extension RealmFactory: IRealmFactory {

    var realm: Realm {
        return try! Realm(configuration: configuration)
    }

}
