import OpenSslKit
import BitcoinCore

class ScryptHasher: IHasher {

    init() {}

    func hash(data: Data) -> Data {
        OpenSslKit.Kit.scrypt(pass: data)
    }

}
