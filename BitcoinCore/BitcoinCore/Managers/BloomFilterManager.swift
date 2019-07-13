class BloomFilterManager {
    class BloomFilterExpired: Error {}

    private var providers = [IBloomFilterProvider]()

    private let storage: IStorage
    private let factory: IFactory
    weak var delegate: IBloomFilterManagerDelegate?

    var bloomFilter: BloomFilter?

    init(storage: IStorage, factory: IFactory) {
        self.storage = storage
        self.factory = factory
    }

    private func needToSetToBloomFilter(output: OutputWithPublicKey, bestBlockHeight: Int) -> Bool {
        // Need to set if output is unspent
        guard let _ = output.spendingInput else {
            return true
        }

        if let spendingBlockHeight = output.spendingBlockHeight {
            // If output is spent, we still need to set to bloom filter if it hasn't at least 100 confirmations 
            return bestBlockHeight - spendingBlockHeight < 100
        }

        // if output is spent by a mempool transaction, that is, spending input's transaction has not a block
        return true
    }
}

extension BloomFilterManager: IBloomFilterManager {

    func add(provider: IBloomFilterProvider) {
        providers.append(provider)
    }

    func regenerateBloomFilter() {
        var elements = [Data]()

        let publicKeys = storage.publicKeys()
        for publicKey in publicKeys {
            elements.append(publicKey.keyHash)
            elements.append(publicKey.raw)
            elements.append(publicKey.scriptHashForP2WPKH)
        }

        var outputs = storage.outputsWithPublicKeys().filter { output in
            return output.output.scriptType == ScriptType.p2wpkh || output.output.scriptType == ScriptType.p2pk || output.output.scriptType == ScriptType.p2wpkhSh
        }

        if let bestBlockHeight = storage.lastBlock?.height {
            outputs = outputs.filter {
                self.needToSetToBloomFilter(output: $0, bestBlockHeight: bestBlockHeight)
            }
        }

        for outputWithPublicKey in outputs {
            let outpoint = outputWithPublicKey.output.transactionHash + byteArrayLittleEndian(int: outputWithPublicKey.output.index)
            elements.append(outpoint)
        }

        for provider in providers {
            elements.append(contentsOf: provider.filterElements())
        }

        if !elements.isEmpty {
            bloomFilter = factory.bloomFilter(withElements: elements)
            delegate?.bloomFilterUpdated(bloomFilter: bloomFilter!)
        }
    }

}
