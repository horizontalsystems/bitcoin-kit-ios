import Foundation

class KitStateProvider: IKitStateProvider {

    weak var delegate: IKitStateProviderDelegate?

    private var initialBestBlockHeight: Int32 = 0
    private var currentBestBlockHeight: Int32 = 0

}

extension KitStateProvider: ISyncStateListener {

    func syncStarted() {
        delegate?.handleKitStateUpdate(state: BitcoinKit.KitState.syncing(progress: 0))
    }

    func syncStopped() {
        delegate?.handleKitStateUpdate(state: BitcoinKit.KitState.notSynced)
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
        var progress: Double = 0

        if allBlocksToDownload <= 0 || allBlocksToDownload <= blocksDownloaded {
            progress = 1.0
        } else {
            progress = Double(blocksDownloaded) / Double(allBlocksToDownload)
        }

        if progress >= 1 {
            delegate?.handleKitStateUpdate(state: BitcoinKit.KitState.synced)
        } else {
            delegate?.handleKitStateUpdate(state: BitcoinKit.KitState.syncing(progress: progress))
        }
    }

}
