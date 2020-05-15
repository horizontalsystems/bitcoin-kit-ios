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

    private func fetchRecursive(account: Int, external: Bool, publicKeys: [PublicKey] = [], blockHashes: [BlockHash] = [], prevCount: Int = 0, prevLastUsedIndex: Int = -1, startIndex: Int = 0) -> Single<([PublicKey], [BlockHash])> {
        let maxHeight = self.maxHeight

        let count = gapLimit - prevCount + prevLastUsedIndex + 1
        let newPublicKeys: [PublicKey]
        do {
            newPublicKeys = try wallet.publicKeys(account: account, indices: UInt32(startIndex)..<UInt32(startIndex + count), external: external)
        } catch {
            return Single.error(error)
        }

        return blockHashFetcher.getBlockHashes(publicKeys: newPublicKeys).flatMap { [weak self] fetcherResult -> Single<([PublicKey], [BlockHash])> in
            let resultBlockHashes = blockHashes + fetcherResult.responses.filter { $0.height <= maxHeight }
            let resultPublicKeys = publicKeys + newPublicKeys

            let finishSingle = Single.just((resultPublicKeys, resultBlockHashes))
            if fetcherResult.lastUsedIndex < 0 {
                return finishSingle
            } else {
                return self?.fetchRecursive(account: account, external: external, publicKeys: resultPublicKeys, blockHashes: resultBlockHashes, prevCount: count, prevLastUsedIndex: fetcherResult.lastUsedIndex, startIndex: startIndex + count) ?? finishSingle
            }
        }
    }

}

extension BlockDiscoveryBatch: IBlockDiscovery {

    func discoverBlockHashes(account: Int, external: Bool) -> Single<([PublicKey], [BlockHash])> {
        fetchRecursive(account: account, external: external)
    }

}
