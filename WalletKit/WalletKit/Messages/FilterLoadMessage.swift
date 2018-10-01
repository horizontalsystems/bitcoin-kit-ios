import Foundation

struct FilterLoadMessage: IMessage {
    /// The filter itself is simply a bit field of arbitrary byte-aligned size. The maximum size is 36,000 bytes.
    let filter: Data
    /// The number of hash functions to use in this filter. The maximum value allowed in this field is 50.
    let nHashFuncs: UInt32
    /// A random value to add to the seed value in the hash function used by the bloom filter.
    let nTweak: UInt32
    /// A set of flags that control how matched items are added to the filter.
    let nFlags: UInt8

    init(filter: Data, nHashFuncs: UInt32, nTweak: UInt32, nFlags: UInt8) {
        self.filter = filter
        self.nHashFuncs = nHashFuncs
        self.nTweak = nTweak
        self.nFlags = nFlags
    }

    init(data: Data, network: NetworkProtocol) {
        filter = Data()
        nHashFuncs = 0
        nTweak = 0
        nFlags = 0
    }

    func serialized() -> Data {
        var data = Data()
        data += VarInt(filter.count).serialized()
        data += filter
        data += nHashFuncs
        data += nTweak
        data += nFlags
        return data
    }

}
