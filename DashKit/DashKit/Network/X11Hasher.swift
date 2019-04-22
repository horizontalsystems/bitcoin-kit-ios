import HSCryptoX11
import BitcoinCore

class X11Hasher: IDashHasher, IHasher {

    func hash(data: Data) -> Data {
        return CryptoX11.x11(from: data)
    }

}
