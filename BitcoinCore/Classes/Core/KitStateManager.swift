import Foundation

class KitStateManager {

    weak var delegate: IKitStateManagerDelegate?

    private var initialBestBlockHeight: Int32 = 0
    private var currentBestBlockHeight: Int32 = 0
    private var foundTransactionsCount: Int = 0

    private(set) var syncState: BitcoinCore.KitState = .notSynced(error: BitcoinCore.StateError.notStarted) {
        didSet {
            if !(oldValue == syncState) {
                delegate?.handleKitStateUpdate(state: syncState)
            }
        }
    }

    var syncIdle: Bool {
        guard case .notSynced(error: let error) = syncState else {
            return false
        }

        if let stateError = error as? BitcoinCore.StateError, stateError == .notStarted {
            return false
        }

        return true
    }

}

extension KitStateManager: IKitStateManager {

    func setApiSyncStarted() {
        syncState = .apiSyncing(transactions: foundTransactionsCount)
    }

    func setBlocksSyncStarted() {
        syncState = .syncing(progress: 0)
    }

    func setSyncFailed(error: Error) {
        syncState = .notSynced(error: error)
    }

}

extension KitStateManager: IApiSyncListener {

    func transactionsFound(count: Int) {
        foundTransactionsCount += count
        syncState = .apiSyncing(transactions: foundTransactionsCount)
    }

}

extension KitStateManager: IBlockSyncListener {


    func initialBestBlockHeightUpdated(height: Int32) {
        initialBestBlockHeight = height
        currentBestBlockHeight = height
    }

    func blocksSyncFinished() {
        syncState = .synced
    }

    func currentBestBlockHeightUpdated(height: Int32, maxBlockHeight: Int32) {
        if currentBestBlockHeight < height {
            currentBestBlockHeight = height
        }

        let blocksDownloaded = currentBestBlockHeight - initialBestBlockHeight
        let allBlocksToDownload = maxBlockHeight - initialBestBlockHeight
        var progress: Double = 0

        if allBlocksToDownload <= 0 || allBlocksToDownload <= blocksDownloaded {
            progress = 1.0
        } else {
            progress = Double(blocksDownloaded) / Double(allBlocksToDownload)
        }

        if progress >= 1 {
            syncState = .synced
        } else {
            syncState = .syncing(progress: progress)
        }
    }

}
