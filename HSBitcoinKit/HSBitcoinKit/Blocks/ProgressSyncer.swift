import Foundation

class ProgressSyncer: IProgressSyncer {

    weak var delegate: ProgressSyncerDelegate?

    private var initialBestBlockHeight: Int32 = 0
    private var currentBestBlockHeight: Int32 = 0
    private var maxBlockHeight: Int32 = 0

    private func notifyListener() {
        let blocksDownloaded = currentBestBlockHeight - initialBestBlockHeight
        let allBlocksToDownload = maxBlockHeight - initialBestBlockHeight
        var progress: Double = 0

        if allBlocksToDownload <= 0 {
            progress = 1.0
        } else {
            progress = Double(blocksDownloaded) / Double(allBlocksToDownload)
        }

        if progress > 1 {
            progress = 1.0
        }

        delegate?.handleProgressUpdate(progress: progress)
    }

}

extension ProgressSyncer: BestBlockHeightListener {

    func bestBlockHeightReceived(height: Int32) {
        maxBlockHeight = height
        notifyListener()
    }

}

extension ProgressSyncer: BlockSyncerListener {

    func initialBestBlockHeightUpdated(height: Int32) {
        initialBestBlockHeight = height
        currentBestBlockHeight = height
    }

    func currentBestBlockHeightUpdated(height: Int32) {
        if currentBestBlockHeight < height {
            currentBestBlockHeight = height
        }

        notifyListener()
    }

}
