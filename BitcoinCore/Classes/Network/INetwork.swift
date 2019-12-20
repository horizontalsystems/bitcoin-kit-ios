import Foundation

public extension INetwork {
    var protocolVersion: Int32 { 70015 }
    var maxBlockSize: UInt32 { 1_000_000 }
    var serviceFullNode: UInt64 { 1 }

    var lastCheckpointBlock: Block {
        let podBundle = Bundle(for: type(of: self))

        guard let checkpointsBundleURL = podBundle.url(forResource: bundleName, withExtension: "bundle"),
              let checkpointsBundle = Bundle(url: checkpointsBundleURL),
              let fileURL = checkpointsBundle.url(forResource: name, withExtension: "checkpoint"),
              let string = try? String(contentsOf: fileURL, encoding: .utf8),
              let data = Data(hex: string) else {
            return bip44CheckpointBlock
        }

        let byteStream = ByteStream(data)

        let version = Int(byteStream.read(Int32.self))
        let previousBlockHeaderHash = byteStream.read(Data.self, count: 32)
        let merkleRoot = byteStream.read(Data.self, count: 32)
        let timestamp = Int(byteStream.read(UInt32.self))
        let bits = Int(byteStream.read(UInt32.self))
        let nonce = Int(byteStream.read(UInt32.self))
        let height = Int(byteStream.read(UInt32.self))
        let headerHash = byteStream.read(Data.self, count: 32)

        return Block(
                withHeader: BlockHeader(
                        version: version, headerHash: headerHash, previousBlockHeaderHash: previousBlockHeaderHash, merkleRoot: merkleRoot,
                        timestamp: timestamp, bits: bits, nonce: nonce
                ),
                height: height
        )
    }
}
