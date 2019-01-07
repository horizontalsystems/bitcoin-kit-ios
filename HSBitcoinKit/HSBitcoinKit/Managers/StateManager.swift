import RealmSwift

class StateManager {
    private let realmFactory: IRealmFactory

    init(realmFactory: IRealmFactory, syncableFromApi: Bool, newWallet: Bool) {
        self.realmFactory = realmFactory

        if !syncableFromApi || newWallet {
            self.restored = true
        }
    }

    private func getRestoreState() -> RestoreState {
        return realmFactory.realm.objects(RestoreState.self).first ?? RestoreState()
    }

    private func setRestoreState(_ block: (RestoreState) -> ()) {
        let realm = realmFactory.realm

        let restoreState = realm.objects(RestoreState.self).first ?? RestoreState()

        try? realm.write {
            block(restoreState)
            realm.add(restoreState, update: true)
        }
    }

}

extension StateManager: IStateManager {

    var restored: Bool {
        get {
            return getRestoreState().restored
        }
        set {
            setRestoreState { kitState in
                kitState.restored = newValue
            }
        }
    }

}
