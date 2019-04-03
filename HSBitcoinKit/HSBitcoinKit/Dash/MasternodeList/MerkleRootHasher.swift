import HSCryptoKit
import Foundation

class MerkleRootHasher: IHasher {

    func hash(data: Data) -> Data {
        return CryptoKit.sha256sha256(data)
    }

}

extension MerkleRootHasher: IMerkleHasher {

    func hash(left: Data, right: Data) -> Data {
        let concatedData = Data(left) + Data(right)

        return Data(CryptoKit.sha256sha256(concatedData))
    }

}
