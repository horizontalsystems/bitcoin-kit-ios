struct FilterLoadMessage: IMessage {
    let bloomFilter: BloomFilter

    init(bloomFilter: BloomFilter) {
        self.bloomFilter = bloomFilter
    }

    var description: String {
        return "\(bloomFilter.elementsCount) item(s)"
    }

}
