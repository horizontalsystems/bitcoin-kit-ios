class BloomFilterManager {
    class BloomFilterExpired: Error {}

    private let storage: IStorage
    private let factory: IFactory
    weak var delegate: BloomFilterManagerDelegate?

    var bloomFilter: BloomFilter?

    init(storage: IStorage, factory: IFactory) {
        self.storage = storage
        self.factory = factory
    }

    // This method is a workaround
    private func byteArrayLittleEndian(int: Int) -> [UInt8] {
        return [
            UInt8(int & 0x000000FF),
            UInt8((int & 0x0000FF00) >> 8),
            UInt8((int & 0x00FF0000) >> 16),
            UInt8((int & 0xFF000000) >> 24)
        ]
    }

    private func needToSetToBloomFilter(output: OutputWithPublicKey, bestBlockHeight: Int) -> Bool {
        // Need to set if output is unspent
        let inputs = storage.inputsWithBlock(ofOutput: output.output)
        if inputs.count == 0 {
            return true
        }

        if let outputSpentBlockHeight = inputs.first?.block?.height {
            // If output is spent, we still need to set to bloom filter if it hasn't at least 100 confirmations 
            return bestBlockHeight - outputSpentBlockHeight < 100
        }

        // if output is spent by a mempool transaction, that is, spending input's transaction has not a block
        return true
    }
}

extension BloomFilterManager: IBloomFilterManager {

    func regenerateBloomFilter() {
        var elements = [Data]()

        let publicKeys = storage.publicKeys()
        for publicKey in publicKeys {
            elements.append(publicKey.keyHash)
            elements.append(publicKey.raw)
            elements.append(publicKey.scriptHashForP2WPKH)
        }

        var outputs = storage.outputsWithPublicKeys().filter { output in
            return output.output.scriptType == ScriptType.p2wpkh || output.output.scriptType == ScriptType.p2pk
        }

        if let bestBlockHeight = storage.lastBlock?.height {
            outputs = outputs.filter {
                self.needToSetToBloomFilter(output: $0, bestBlockHeight: bestBlockHeight)
            }
        }

        for output in outputs {
            if let transaction = output.output.transaction(storage: storage) {
                let outpoint = transaction.dataHash + byteArrayLittleEndian(int: output.output.index)
                elements.append(outpoint)
            }
        }

        if !elements.isEmpty {
            let bloomFilter = factory.bloomFilter(withElements: elements)
            if self.bloomFilter?.filter != bloomFilter.filter {
                self.bloomFilter = bloomFilter
                delegate?.bloomFilterUpdated(bloomFilter: bloomFilter)
            }
        }
    }

}
