import RealmSwift

class RealmStorage {
    private let realmFactory: IRealmFactory

    init(realmFactory: IRealmFactory) {
        self.realmFactory = realmFactory
    }

}

extension RealmStorage: IFeeRateStorage {

    var feeRate: FeeRate? {
        return realmFactory.realm.objects(FeeRate.self).first
    }

    func save(feeRate: FeeRate) {
        let realm = realmFactory.realm

        try? realm.write {
            realm.add(feeRate, update: true)
        }
    }

    func clear() {
        let realm = realmFactory.realm

        try? realm.write {
            realm.delete(realm.objects(FeeRate.self))
        }
    }

}