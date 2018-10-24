import RealmSwift

class BloomFilterManager {
    class BloomFilterExpired: Error {}

    private let realmFactory: IRealmFactory
    weak var delegate: BloomFilterManagerDelegate?

    var bloomFilter: BloomFilter?

    init(realmFactory: IRealmFactory) {
        self.realmFactory = realmFactory
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

    private func needToSetToBloomFilter(output: TransactionOutput, bestBlockHeight: Int) -> Bool {
        // Need to set if output is unspent
        if output.inputs.count == 0 {
            return true
        }

        if let outputSpentBlockHeight = output.inputs.first?.transaction?.block?.height {
            // If output is spent, we still need to set to bloom filter if it hasn't at least 100 confirmations 
            return bestBlockHeight - outputSpentBlockHeight < 100
        }

        // if output is spent by a mempool transaction, that is, spending input's transaction has not a block
        return true
    }
}

extension BloomFilterManager: IBloomFilterManager {

    func regenerateBloomFilter() {
        let realm = realmFactory.realm
        var elements = [Data]()

        let publicKeys = realm.objects(PublicKey.self)
        for publicKey in publicKeys {
            elements.append(publicKey.keyHash)
            elements.append(publicKey.raw)
            elements.append(publicKey.scriptHashForP2WPKH)
        }

        var transactionOutputs = Array(
                realm.objects(TransactionOutput.self)
                        .filter("publicKey != nil")
                        .filter("scriptType = %@ OR scriptType = %@", ScriptType.p2wpkh.rawValue, ScriptType.p2pk.rawValue)
        )

        if let bestBlockHeight = realm.objects(Block.self).sorted(byKeyPath: "height").last?.height {
            transactionOutputs = transactionOutputs.filter {
                self.needToSetToBloomFilter(output: $0, bestBlockHeight: bestBlockHeight)
            }
        }

        for output in transactionOutputs {
            if let transaction = output.transaction {
                let outpoint = transaction.dataHash + byteArrayLittleEndian(int: output.index)
                elements.append(outpoint)
            }
        }

        if !elements.isEmpty {
            let bloomFilter = BloomFilter(elements: elements)
            if self.bloomFilter?.filter != bloomFilter.filter {
                self.bloomFilter = bloomFilter
                delegate?.bloomFilterUpdated(bloomFilter: bloomFilter)
            }
        }
    }

}

protocol BloomFilterManagerDelegate: class {
    func bloomFilterUpdated(bloomFilter: BloomFilter)
}
