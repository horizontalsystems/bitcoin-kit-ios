class WatchedTransactionManager {

    struct P2ShOutputFilter  {
        let hash: Data
        let delegate: IWatchedTransactionDelegate
    }

    struct OutpointFilter  {
        let transactionHash: Data
        let outputIndex: Int
        let delegate: IWatchedTransactionDelegate
    }

    private var p2ShOutputFilters = [P2ShOutputFilter]()
    private var outpointFilters = [OutpointFilter]()
    private let queue: DispatchQueue
    weak var bloomFilterManager: IBloomFilterManager?

    init(queue: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.watched-transactions-manager", qos: .background)) {
        self.queue = queue
    }

    private func scan(transaction: FullTransaction) {
        for filter in p2ShOutputFilters {
            for output in transaction.outputs {
                if output.scriptType == .p2sh && output.keyHash == filter.hash {
                    filter.delegate.transactionReceived(transaction: transaction, outputIndex: output.index)
                    return
                }
            }
        }

        for filter in outpointFilters {
            for (index, input) in transaction.inputs.enumerated() {
                if input.previousOutputTxHash == filter.transactionHash && input.previousOutputIndex == filter.outputIndex {
                    filter.delegate.transactionReceived(transaction: transaction, inputIndex: index)
                    return
                }
            }
        }
    }

}

extension WatchedTransactionManager : IWatchedTransactionManager {

    func add(transactionFilter: BitcoinCore.TransactionFilter, delegatedTo delegate: IWatchedTransactionDelegate) {
        switch transactionFilter {
        case .p2shOutput(let scriptHash):
            p2ShOutputFilters.append(P2ShOutputFilter(hash: scriptHash, delegate: delegate))
        case .outpoint(let transactionHash, let outputIndex):
            outpointFilters.append(OutpointFilter(transactionHash: transactionHash, outputIndex: outputIndex, delegate: delegate))
        }
        bloomFilterManager?.regenerateBloomFilter()
    }

}

extension WatchedTransactionManager : ITransactionListener {

    func onReceive(transaction: FullTransaction) {
        queue.async {
            self.scan(transaction: transaction)
        }
    }

}

extension WatchedTransactionManager : IBloomFilterProvider {

    func filterElements() -> [Data] {
        var elements = [Data]()

        for filter in p2ShOutputFilters {
            elements.append(filter.hash)
        }

        for filter in outpointFilters {
            elements.append(filter.transactionHash + byteArrayLittleEndian(int: filter.outputIndex))
        }

        return elements
    }

}
