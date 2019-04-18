import HSCryptoX11

class X11Hasher: IHasher {

    func hash(data: Data) -> Data {
        return CryptoX11.x11(from: data)
    }

}
