class ApiSyncStateManager {
    private let storage: IStorage
    private let restoreFromApi: Bool

    init(storage: IStorage, restoreFromApi: Bool) {
        self.storage = storage
        self.restoreFromApi = restoreFromApi
    }

}

extension ApiSyncStateManager: IApiSyncStateManager {

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
