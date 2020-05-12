import RxSwift
import HsToolKit

class SyncManager {
    private var disposeBag = DisposeBag()

    private let reachabilityManager: IReachabilityManager
    private let initialSyncer: IInitialSyncer
    private let peerGroup: IPeerGroup
    private let listener: ISyncStateListener
    private let stateManager: IStateManager

    private var state: State = .stopped

    init(reachabilityManager: IReachabilityManager, initialSyncer: IInitialSyncer, peerGroup: IPeerGroup, listener: ISyncStateListener, stateManager: IStateManager) {
        self.reachabilityManager = reachabilityManager
        self.initialSyncer = initialSyncer
        self.peerGroup = peerGroup
        self.listener = listener
        self.stateManager = stateManager

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
        if state == .idle {
            startSync()
        }
    }

    private func onUnreachable() {
        if state == .peerGroupRunning {
            peerGroup.stop()
            state = .idle
            listener.syncStopped(error: ReachabilityManager.ReachabilityError.notReachable)
        }
    }

    private func startPeerGroup() {
        state = .peerGroupRunning
        peerGroup.start()
    }

    private func startSync() {
        listener.syncStarted()

        if stateManager.restored {
            startPeerGroup()
        } else {
            state = .initialSyncing
            initialSyncer.sync()
        }
    }

}

extension SyncManager: ISyncManager {

    func start() {
        guard state == .stopped || state == .idle else {
            return
        }

        guard reachabilityManager.isReachable else {
            state = .idle
            listener.syncStopped(error: ReachabilityManager.ReachabilityError.notReachable)
            return
        }

        startSync()
    }

    func stop() {
        switch state {
        case .initialSyncing:
            initialSyncer.terminate()
        case .peerGroupRunning:
            peerGroup.stop()
        default: ()
        }

        state = .stopped
        listener.syncStopped(error: BitcoinCore.StateError.notStarted)
    }

}

extension SyncManager: IInitialSyncerDelegate {

    func onSyncSuccess() {
        stateManager.restored = true
        startPeerGroup()
    }

    func onSyncFailed(error: Error) {
        state = .idle
        listener.syncStopped(error: error)
    }

}

extension SyncManager {

    enum State {
        case stopped
        case idle
        case initialSyncing
        case peerGroupRunning
    }

}
