import OpenSslKit
import BitcoinCore

class SingleHasher: IDashHasher {

    func hash(data: Data) -> Data {
        OpenSslKit.Kit.sha256(data)
    }

}
