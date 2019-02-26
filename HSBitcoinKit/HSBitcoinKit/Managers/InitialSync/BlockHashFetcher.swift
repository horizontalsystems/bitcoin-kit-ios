import RxSwift

class BlockHashFetcher {
    private let addressSelector: IAddressSelector
    private let apiManager: IBCoinApiManager
    private let helper: IBlockHashFetcherHelper

    init(addressSelector: IAddressSelector, apiManager: IBCoinApiManager, helper: IBlockHashFetcherHelper) {
        self.addressSelector = addressSelector
        self.apiManager = apiManager
        self.helper = helper
    }

}

extension BlockHashFetcher: IBlockHashFetcher {

    func getBlockHashes(publicKeys: [PublicKey]) -> Observable<(responses: [BlockResponse], lastUsedIndex: Int)> {
        let addresses = publicKeys.map {
            addressSelector.getAddressVariants(publicKey: $0)
        }

        return apiManager.getTransactions(addresses: addresses.flatMap { $0 }).map { [weak self] transactionResponses -> (responses: [BlockResponse], lastUsedIndex: Int) in
            if transactionResponses.isEmpty {
                return (responses: [], lastUsedIndex: -1)
            }

            let lastUsedIndex = self?.helper.lastUsedIndex(addresses: addresses, outputs: transactionResponses.flatMap { $0.txOutputs })

            let blockResponses: [BlockResponse] = transactionResponses.compactMap {
                BlockResponse(hash: $0.blockHash, height: $0.blockHeight)
            }

            return (responses: blockResponses, lastUsedIndex: lastUsedIndex ?? -1)
        }
    }

}
