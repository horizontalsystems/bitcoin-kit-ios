import OpenSslKit
import BitcoinCore

class SingleHasher: IDashHasher {

    func hash(data: Data) -> Data {
        return Kit.sha256(data)
    }

}
