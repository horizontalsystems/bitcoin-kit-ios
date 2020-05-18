import Foundation
import RxSwift
import ObjectMapper
import HsToolKit

class BlockDiscoveryBatch {
    private let wallet: IHDWallet
    private let blockHashFetcher: IBlockHashFetcher

    private let maxHeight: Int
    private let gapLimit: Int

    init(checkpoint: Checkpoint, wallet: IHDWallet, blockHashFetcher: IBlockHashFetcher, logger: Logger? = nil) {
        self.wallet = wallet
        self.blockHashFetcher = blockHashFetcher

        maxHeight = checkpoint.block.height
        gapLimit = wallet.gapLimit
    }

    private func fetchRecursive(account: Int, blockHashes: [BlockHash] = [], externalBatchInfo: KeyBlockHashBatchInfo = KeyBlockHashBatchInfo(), internalBatchInfo: KeyBlockHashBatchInfo = KeyBlockHashBatchInfo()) -> Single<([PublicKey], [BlockHash])> {
        let maxHeight = self.maxHeight

        let externalCount = gapLimit - externalBatchInfo.prevCount + externalBatchInfo.prevLastUsedIndex + 1
        let internalCount = gapLimit - internalBatchInfo.prevCount + internalBatchInfo.prevLastUsedIndex + 1

        var externalNewKeys = [PublicKey]()
        var internalNewKeys = [PublicKey]()

        do {
            externalNewKeys.append(contentsOf: try wallet.publicKeys(account: account, indices: UInt32(externalBatchInfo.startIndex)..<UInt32(externalBatchInfo.startIndex + externalCount), external: true))
            internalNewKeys.append(contentsOf: try wallet.publicKeys(account: account, indices: UInt32(internalBatchInfo.startIndex)..<UInt32(internalBatchInfo.startIndex + internalCount), external: false))
        } catch {
            return Single.error(error)
        }

        return blockHashFetcher.getBlockHashes(externalKeys: externalNewKeys, internalKeys: internalNewKeys).flatMap { [weak self] fetcherResponse -> Single<([PublicKey], [BlockHash])> in
            let resultBlockHashes = blockHashes + fetcherResponse.blockHashes.filter { $0.height <= maxHeight }
            let externalPublicKeys = externalBatchInfo.publicKeys + externalNewKeys
            let internalPublicKeys = internalBatchInfo.publicKeys + internalNewKeys

            let finishSingle = Single.just((externalPublicKeys + internalPublicKeys, resultBlockHashes))

            if fetcherResponse.externalLastUsedIndex < 0 && fetcherResponse.internalLastUsedIndex < 0 {
                return finishSingle
            } else {
                let externalBatch = KeyBlockHashBatchInfo(publicKeys: externalPublicKeys, prevCount: externalCount, prevLastUsedIndex: fetcherResponse.externalLastUsedIndex, startIndex: externalBatchInfo.startIndex + externalCount)
                let internalBatch = KeyBlockHashBatchInfo(publicKeys: internalPublicKeys, prevCount: internalCount, prevLastUsedIndex: fetcherResponse.internalLastUsedIndex, startIndex: internalBatchInfo.startIndex + internalCount)

                return self?.fetchRecursive(account: account, blockHashes: resultBlockHashes, externalBatchInfo: externalBatch, internalBatchInfo: internalBatch) ?? finishSingle
            }
        }
    }

}

extension BlockDiscoveryBatch: IBlockDiscovery {

    func discoverBlockHashes(account: Int) -> Single<([PublicKey], [BlockHash])> {
        fetchRecursive(account: account)
    }

}

class KeyBlockHashBatchInfo {
    var publicKeys: [PublicKey]
    var prevCount: Int
    var prevLastUsedIndex: Int
    var startIndex: Int

    init(publicKeys: [PublicKey] = [], prevCount: Int = 0, prevLastUsedIndex: Int = -1, startIndex: Int = 0) {
        self.publicKeys = publicKeys
        self.prevCount = prevCount
        self.prevLastUsedIndex = prevLastUsedIndex
        self.startIndex = startIndex
    }

}
