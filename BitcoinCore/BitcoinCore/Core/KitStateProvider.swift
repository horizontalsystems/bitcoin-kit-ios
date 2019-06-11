import Foundation

class KitStateProvider: IKitStateProvider {

    weak var delegate: IKitStateProviderDelegate?

    private var initialBestBlockHeight: Int32 = 0
    private var currentBestBlockHeight: Int32 = 0

    private(set) var syncState: BitcoinCore.KitState = .notSynced {
        didSet {
            if !(oldValue == syncState) {
                delegate?.handleKitStateUpdate(state: syncState)
            }
        }
    }

}

extension KitStateProvider: ISyncStateListener {

    func syncStarted() {
        syncState = .syncing(progress: 0)
    }

    func syncStopped() {
        syncState = .notSynced
    }

    func syncFinished(all: Bool) {
        syncState = all ? .synced : .syncing(progress: 1)
    }

    func initialBestBlockHeightUpdated(height: Int32) {
        initialBestBlockHeight = height
        currentBestBlockHeight = height
    }

    func currentBestBlockHeightUpdated(height: Int32, maxBlockHeight: Int32) {
        if currentBestBlockHeight < height {
            currentBestBlockHeight = height
        }

        let blocksDownloaded = currentBestBlockHeight - initialBestBlockHeight
        let allBlocksToDownload = maxBlockHeight - initialBestBlockHeight

        if allBlocksToDownload > 0 && allBlocksToDownload > blocksDownloaded {
            syncState = .syncing(progress: Double(blocksDownloaded) / Double(allBlocksToDownload))
        }
    }

}
