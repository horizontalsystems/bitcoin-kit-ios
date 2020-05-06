import RxSwift

class BlockHashFetcher {
    private let restoreKeyConverter: IRestoreKeyConverter
    private let apiManager: ISyncTransactionApi
    private let helper: IBlockHashFetcherHelper

    init(restoreKeyConverter: IRestoreKeyConverter, apiManager: ISyncTransactionApi, helper: IBlockHashFetcherHelper) {
        self.restoreKeyConverter = restoreKeyConverter
        self.apiManager = apiManager
        self.helper = helper
    }

}

extension BlockHashFetcher: IBlockHashFetcher {

    func getBlockHashes(publicKeys: [PublicKey]) -> Single<(responses: [BlockHash], lastUsedIndex: Int)> {
        let addresses = publicKeys.map {
            restoreKeyConverter.keysForApiRestore(publicKey: $0)
        }

        return apiManager.getTransactions(addresses: addresses.flatMap { $0 }).map { [weak self] transactionResponses -> (responses: [BlockHash], lastUsedIndex: Int) in
            if transactionResponses.isEmpty {
                return (responses: [], lastUsedIndex: -1)
            }

            let lastUsedIndex = self?.helper.lastUsedIndex(addresses: addresses, outputs: transactionResponses.flatMap { $0.txOutputs })

            let blockHashes: [BlockHash] = transactionResponses.compactMap {
                BlockHash(headerHashReversedHex: $0.blockHash, height: $0.blockHeight, sequence: 0)
            }

            return (responses: blockHashes, lastUsedIndex: lastUsedIndex ?? -1)
        }
    }

}
