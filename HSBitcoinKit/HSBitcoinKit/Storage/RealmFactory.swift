import RealmSwift

class RealmFactory {
    private let configuration: Realm.Configuration

    init(realmFileName: String) {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        configuration = Realm.Configuration(
                fileURL: documentsUrl?.appendingPathComponent(realmFileName),
                objectTypes: [
                    Block.self,
                    BlockHash.self,
                    BlockHeader.self,
                    FeeRate.self,
                    RestoreState.self,
                    PeerAddress.self,
                    PublicKey.self,
                    SentTransaction.self,
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
