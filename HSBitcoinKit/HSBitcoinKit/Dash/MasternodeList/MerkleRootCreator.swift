class MerkleRootCreator: IMerkleRootCreator {
    let hasher: IMerkleHasher

    init(hasher: IMerkleHasher) {
        self.hasher = hasher
    }

    func create(hashes: [Data]) -> Data? {
        guard !hashes.isEmpty else {
            return nil
        }

        let hashesCount = hashes.count

        var roundCount = hashesCount == 1 ? 1 : Int(log2(Double(hashesCount)))
        if hashesCount - roundCount > 0 {
            roundCount += 1
        }

        var hashes = hashes
        for _ in 0..<roundCount {
            let hashesCount = hashes.count
            // make list even
            if hashesCount % 2 == 1 {
                hashes.append(hashes[hashesCount - 1])
            }

            var newHashes = [Data]()
            for i in 0..<(hashes.count / 2) {
                newHashes.append(hasher.hash(left: hashes[2 * i], right: hashes[2 * i + 1]))
            }
            hashes = newHashes
        }

        return hashes.first
    }

}
