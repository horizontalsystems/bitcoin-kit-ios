class BlockHeaderParser: IBlockHeaderParser {
    private let hasher: IHasher

    init(hasher: IHasher) {
        self.hasher = hasher
    }

    func parse(byteStream: ByteStream) -> BlockHeader {
        let version = Int(byteStream.read(Int32.self))
        let previousBlockHeaderHash = byteStream.read(Data.self, count: 32)
        let merkleRoot = byteStream.read(Data.self, count: 32)
        let timestamp = Int(byteStream.read(UInt32.self))
        let bits = Int(byteStream.read(UInt32.self))
        let nonce = Int(byteStream.read(UInt32.self))

        let headerData = byteStream.data.prefix(80)
        let headerHash = hasher.hash(data: headerData)

        return BlockHeader(
                version: version, headerHash: headerHash, previousBlockHeaderHash: previousBlockHeaderHash, merkleRoot: merkleRoot,
                timestamp: timestamp, bits: bits, nonce: nonce
        )
    }

}
