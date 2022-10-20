class PendingOutpointsProvider {
    private let storage: IStorage

    weak var bloomFilterManager: IBloomFilterManager?

    init(storage: IStorage) {
        self.storage = storage
    }

}

extension PendingOutpointsProvider: IBloomFilterProvider {

    func filterElements() -> [Data] {
        let hashes = storage.incomingPendingTransactionHashes()

        return storage.inputs(byHashes: hashes).map {
            $0.previousOutputTxHash + byteArrayLittleEndian(int: $0.previousOutputIndex)
        }
    }

}