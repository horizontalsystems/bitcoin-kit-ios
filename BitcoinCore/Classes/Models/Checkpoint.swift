import UIExtensions

public struct Checkpoint {
    public let block: Block
    public let additionalBlocks: [Block]

    public init(block: Block, additionalBlocks: [Block]) {
        self.block = block
        self.additionalBlocks = additionalBlocks
    }

    public init(podBundle: Bundle, bundleName: String, filename: String) throws {
        guard let checkpointsBundleURL = podBundle.url(forResource: bundleName, withExtension: "bundle") else {
            throw ParseError.invalidBundleUrl
        }
        guard let checkpointsBundle = Bundle(url: checkpointsBundleURL) else {
            throw ParseError.invalidBundle
        }
        guard let fileURL = checkpointsBundle.url(forResource: filename, withExtension: "checkpoint") else {
            throw ParseError.invalidFileUrl
        }

        let string = try String(contentsOf: fileURL, encoding: .utf8)
        var lines = string.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw ParseError.invalidFile
        }

        block = try Checkpoint.readBlock(string: lines.removeFirst())
        additionalBlocks = try lines.map { try Checkpoint.readBlock(string: $0) }
    }

    private static func readBlock(string: String) throws -> Block {
        guard let data = Data(hex: string) else {
            throw ParseError.invalidFile
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

        let header = BlockHeader(
                version: version,
                headerHash: headerHash,
                previousBlockHeaderHash: previousBlockHeaderHash,
                merkleRoot: merkleRoot,
                timestamp: timestamp,
                bits: bits,
                nonce: nonce
        )

        return Block(withHeader: header, height: height)
    }

}

public extension Checkpoint {

    enum ParseError: Error {
        case invalidBundleUrl
        case invalidBundle
        case invalidFileUrl
        case invalidFile
    }

}
