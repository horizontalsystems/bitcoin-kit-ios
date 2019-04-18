import HSCryptoKit
import Foundation

class MerkleRootHasher: IHasher {

    func hash(data: Data) -> Data {
        return CryptoKit.sha256sha256(data)
    }

}
