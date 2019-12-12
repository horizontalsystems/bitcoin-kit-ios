class StateManager {
    private let storage: IStorage
    private let restoreFromApi: Bool

    init(storage: IStorage, restoreFromApi: Bool) {
        self.storage = storage
        self.restoreFromApi = restoreFromApi
    }

}

extension StateManager: IStateManager {

    var restored: Bool {
        get {
            guard restoreFromApi else {
                return true
            }

            return storage.initialRestored ?? false
        }
        set {
            storage.set(initialRestored: newValue)
        }
    }

}
