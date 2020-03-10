import OpenSslKit
import BitcoinCore

class ScryptHasher: IHasher {

    init() {}

    func hash(data: Data) -> Data {
        Kit.scrypt(pass: data)
    }

}
