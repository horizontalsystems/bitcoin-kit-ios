import Foundation
import HSCryptoKit

struct FilterLoadMessage: IMessage {
    let bloomFilter: BloomFilter

    init(bloomFilter: BloomFilter) {
        self.bloomFilter = bloomFilter
    }

    init(data: Data) {
        self.bloomFilter = BloomFilter(elements: [Data]())
    }

    func serialized() -> Data {
        var data = Data()
        data += VarInt(bloomFilter.filter.count).serialized()
        data += bloomFilter.filter
        data += bloomFilter.nHashFuncs
        data += bloomFilter.nTweak
        data += bloomFilter.nFlag
        return data
    }

}
