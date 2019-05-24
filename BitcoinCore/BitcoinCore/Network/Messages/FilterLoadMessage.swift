struct FilterLoadMessage: IMessage {
    let bloomFilter: BloomFilter

    init(bloomFilter: BloomFilter) {
        self.bloomFilter = bloomFilter
    }

}
