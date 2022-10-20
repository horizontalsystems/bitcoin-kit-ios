import X11Kit
import BitcoinCore

class X11Hasher: IDashHasher, IHasher {

    func hash(data: Data) -> Data {
        X11Kit.Kit.x11(from: data)
    }

}
