import HSCryptoKit
import BitcoinCore

class SingleHasher: IDashHasher {

    func hash(data: Data) -> Data {
        return CryptoKit.sha256(data)
    }

}
