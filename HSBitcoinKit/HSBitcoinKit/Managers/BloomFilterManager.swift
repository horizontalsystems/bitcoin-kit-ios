import RealmSwift

class BloomFilterManager {
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
}

extension BloomFilterManager: IBloomFilterManager {

    func regenerateBloomFilter() {
        let realm = realmFactory.realm
        var elements = [Data]()

        let publicKeys = realm.objects(PublicKey.self)
        for publicKey in publicKeys {
            elements.append(publicKey.keyHash)
            elements.append(publicKey.raw!)
            elements.append(publicKey.scriptHashForP2WPKH)
        }

        let unspentOutputs = realm.objects(TransactionOutput.self)
                .filter("publicKey != nil")
                .filter("scriptType = %@ OR scriptType = %@", ScriptType.p2wpkh.rawValue, ScriptType.p2pk.rawValue)
                .filter("inputs.@count = %@", 0)

        for output in unspentOutputs {
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
