import HSCryptoKit
import BitcoinCore

class SingleHasher: IHasher {

    func hash(data: Data) -> Data {
        return CryptoKit.sha256(data)
    }

}
