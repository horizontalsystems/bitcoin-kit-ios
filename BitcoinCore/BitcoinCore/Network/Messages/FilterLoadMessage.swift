import Foundation
import HSCryptoKit

struct FilterLoadMessage: IMessage {
    let command: String = "filterload"

    let bloomFilter: BloomFilter

    init(bloomFilter: BloomFilter) {
        self.bloomFilter = bloomFilter
    }

}
