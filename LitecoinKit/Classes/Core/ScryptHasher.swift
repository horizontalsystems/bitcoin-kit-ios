import OpenSslKit
import BitcoinCore

class ScryptHasher: IHasher {

    init() {}

    func hash(data: Data) -> Data {
        do {
            let params = try ScryptParams(salt: data, n: 1024, r: 1, p: 1, desiredKeyLength: 32)
            let scrypt = Scrypt(params: params)

            return try scrypt.calculate(data: data)
        } catch {
            return Data()
        }
    }

}
