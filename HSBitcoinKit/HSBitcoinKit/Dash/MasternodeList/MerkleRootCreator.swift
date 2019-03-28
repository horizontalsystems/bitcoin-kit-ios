class MerkleRootCreator: IMerkleRootCreator {
    private struct MerkleChunk {
        let first: Data
        let last: Data
    }

    let hasher: IMerkleHasher

    init(hasher: IMerkleHasher) {
        self.hasher = hasher
    }

    func create(hashes: [Data]) -> Data? {
        guard !hashes.isEmpty else {
            return nil
        }
        var tmpHashes = hashes
        repeat {
            tmpHashes = joinHashes(hashes: tmpHashes)
        } while tmpHashes.count > 1
        
        return tmpHashes.first
    }

    private func joinHashes(hashes: [Data]) -> [Data] {
        let chunks = chunked(data: hashes, into: 2)

        return chunks.map {
            hasher.hash(left: $0.first, right: $0.last)
        }
    }

    private func chunked(data: [Data], into size: Int) -> [MerkleChunk] {
        let count = data.count
        return stride(from: 0, to: count, by: size).map {
            let upperBound = max($0, min($0 + size, count) - 1)
            return MerkleChunk(first: data[$0], last: data[upperBound])
        }
    }

}
