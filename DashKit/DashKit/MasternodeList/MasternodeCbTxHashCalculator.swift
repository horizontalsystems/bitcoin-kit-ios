import BitcoinCore

class MasternodeCbTxHasher: IMasternodeCbTxHasher {
    private let coinbaseTransactionSerializer: ICoinbaseTransactionSerializer
    private let hasher: IDashHasher


    init(coinbaseTransactionSerializer: ICoinbaseTransactionSerializer, hasher: IDashHasher) {
        self.coinbaseTransactionSerializer = coinbaseTransactionSerializer
        self.hasher = hasher
    }

    func hash(coinbaseTransaction: CoinbaseTransaction) -> Data {
        let serialized = coinbaseTransactionSerializer.serialize(coinbaseTransaction: coinbaseTransaction)

        return hasher.hash(data: serialized)
    }

}
