import RealmSwift

class StateManager {
    private let realmFactory: IRealmFactory

    init(realmFactory: IRealmFactory) {
        self.realmFactory = realmFactory
    }

    private func getKitState() -> KitState {
        return realmFactory.realm.objects(KitState.self).first ?? KitState()
    }

    private func setKitState(_ block: (KitState) -> ()) {
        let realm = realmFactory.realm

        let kitState = realm.objects(KitState.self).first ?? KitState()

        try? realm.write {
            block(kitState)
            realm.add(kitState, update: true)
        }
    }

}

extension StateManager: IStateManager {

    var apiSynced: Bool {
        get {
            return getKitState().apiSynced
        }
        set {
            setKitState { kitState in
                kitState.apiSynced = newValue
            }
        }
    }

}
