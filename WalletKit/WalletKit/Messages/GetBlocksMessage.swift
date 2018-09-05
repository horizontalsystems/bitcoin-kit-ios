import Foundation

struct GetBlocksMessage: IMessage{
    /// the protocol version
    let version: UInt32
    /// number of block locator hash entries
    let hashCount: VarInt
    /// block locator object; newest back to genesis block (dense to start, but then sparse)
    let blockLocatorHashes: [Data]
    /// hash of the last desired block; set to zero to get as many blocks as possible (500)
    let hashStop: Data

    init(_ data: Data) {
        version = 0
        hashCount = 0
        blockLocatorHashes = [Data]()
        hashStop = Data()
    }

    func serialized() -> Data {
        var data = Data()
        data += version
        data += hashCount.serialized()
        for hash in blockLocatorHashes {
            data += hash
        }
        data += hashStop
        return data
    }
}
