import X11Kit
import BitcoinCore

class X11Hasher: IDashHasher, IHasher {

    func hash(data: Data) -> Data {
        return Kit.x11(from: data)
    }

}
