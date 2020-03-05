import Foundation
import RxSwift
import ObjectMapper

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

    private func fetchRecursive(account: Int, external: Bool, publicKeys: [PublicKey] = [], blockHashes: [BlockHash] = [], prevCount: Int = 0, prevLastUsedIndex: Int = -1, startIndex: Int = 0) -> Observable<([PublicKey], [BlockHash])> {
        let maxHeight = self.maxHeight

        let count = gapLimit - prevCount + prevLastUsedIndex + 1
        var newPublicKeys = [PublicKey]()
        for i in 0..<count {
            do {
                newPublicKeys.append(try wallet.publicKey(account: account, index: i + startIndex, external: external))
            } catch {
                return Observable.error(error)
            }
        }
        return blockHashFetcher.getBlockHashes(publicKeys: newPublicKeys).flatMap { [weak self] fetcherResult -> Observable<([PublicKey], [BlockHash])> in
            let resultBlockHashes = blockHashes + fetcherResult.responses.filter { $0.height <= maxHeight }
            let resultPublicKeys = publicKeys + newPublicKeys

            let finishObservable = Observable.just((resultPublicKeys, resultBlockHashes))
            if fetcherResult.lastUsedIndex < 0 {
                return finishObservable
            } else {
                return self?.fetchRecursive(account: account, external: external, publicKeys: resultPublicKeys, blockHashes: resultBlockHashes, prevCount: count, prevLastUsedIndex: fetcherResult.lastUsedIndex, startIndex: startIndex + count) ?? finishObservable
            }
        }
    }

}

extension BlockDiscoveryBatch: IBlockDiscovery {

    func discoverBlockHashes(account: Int, external: Bool) -> Observable<([PublicKey], [BlockHash])> {
        return fetchRecursive(account: account, external: external)
    }

}
