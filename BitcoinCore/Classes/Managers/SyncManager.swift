import RxSwift
import HsToolKit

class SyncManager {
    private var disposeBag = DisposeBag()

    private let reachabilityManager: IReachabilityManager
    private let initialSyncer: IInitialSyncer
    private let peerGroup: IPeerGroup
    private let stateManager: IKitStateManager
    private let apiSyncStateManager: IApiSyncStateManager

    init(reachabilityManager: IReachabilityManager, initialSyncer: IInitialSyncer, peerGroup: IPeerGroup, stateManager: IKitStateManager, apiSyncStateManager: IApiSyncStateManager) {
        self.reachabilityManager = reachabilityManager
        self.initialSyncer = initialSyncer
        self.peerGroup = peerGroup
        self.stateManager = stateManager
        self.apiSyncStateManager = apiSyncStateManager

        reachabilityManager.reachabilityObservable
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] _ in
                    self?.onReachabilityChanged()
                })
                .disposed(by: disposeBag)
    }

    private func onReachabilityChanged() {
        if reachabilityManager.isReachable {
            onReachable()
        } else {
            onUnreachable()
        }
    }

    private func onReachable() {
        if stateManager.syncIdle {
            startSync()
        }
    }

    private func onUnreachable() {
        if case .syncing(_) = stateManager.syncState {
            peerGroup.stop()
            stateManager.setSyncFailed(error: ReachabilityManager.ReachabilityError.notReachable)
        }
    }

    private func startPeerGroup() {
        stateManager.setBlocksSyncStarted()
        peerGroup.start()
    }

    private func startInitialSync() {
        stateManager.setApiSyncStarted()
        initialSyncer.sync()
    }

    private func startSync() {
        if apiSyncStateManager.restored {
            startPeerGroup()
        } else {
            startInitialSync()
        }
    }

}

extension SyncManager: ISyncManager {

    func start() {
        guard case .notSynced(_) = stateManager.syncState else {
            return
        }

        guard reachabilityManager.isReachable else {
            stateManager.setSyncFailed(error: ReachabilityManager.ReachabilityError.notReachable)
            return
        }

        startSync()
    }

    func stop() {
        switch stateManager.syncState {
        case .apiSyncing:
            initialSyncer.terminate()
        case .syncing:
            peerGroup.stop()
        default: ()
        }

        stateManager.setSyncFailed(error: BitcoinCore.StateError.notStarted)
    }

}

extension SyncManager: IInitialSyncerDelegate {

    func onSyncSuccess() {
        apiSyncStateManager.restored = true
        startPeerGroup()
    }

    func onSyncFailed(error: Error) {
        stateManager.setSyncFailed(error: error)
    }

}
