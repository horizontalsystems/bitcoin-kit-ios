import Foundation

class HDPrivateKey {
    let xPrivKey: UInt32
    let xPubKey: UInt32
    let depth: UInt8
    let fingerprint: UInt32
    let childIndex: UInt32

    let raw: Data
    let chainCode: Data

    init(privateKey: Data, chainCode: Data, xPrivKey: UInt32, xPubKey: UInt32, depth: UInt8, fingerprint: UInt32, childIndex: UInt32) {
        let zeros = privateKey.count < 32 ? [UInt8](repeating: 0, count: 32 - privateKey.count) : []

        self.raw = Data(bytes: zeros) + privateKey
        self.chainCode = chainCode
        self.xPrivKey = xPrivKey
        self.xPubKey = xPubKey
        self.depth = depth
        self.fingerprint = fingerprint
        self.childIndex = childIndex
    }

    convenience init(privateKey: Data, chainCode: Data, xPrivKey: UInt32, xPubKey: UInt32) {
        self.init(privateKey: privateKey, chainCode: chainCode, xPrivKey: xPrivKey, xPubKey: xPubKey, depth: 0, fingerprint: 0, childIndex: 0)
    }

    convenience init(seed: Data, xPrivKey: UInt32, xPubKey: UInt32) {
        let hmac = Crypto.hmacsha512(data: seed, key: "Bitcoin seed".data(using: .ascii)!)
        let privateKey = hmac[0..<32]
        let chainCode = hmac[32..<64]
        self.init(privateKey: privateKey, chainCode: chainCode, xPrivKey: xPrivKey, xPubKey: xPubKey)
    }

    func publicKey() -> HDPublicKey {
        return HDPublicKey(privateKey: self, chainCode: chainCode, xPubKey: xPubKey, depth: depth, fingerprint: fingerprint, childIndex: childIndex)
    }

    func extended() -> String {
        var data = Data()
        data += xPrivKey.bigEndian
        data += depth.littleEndian
        data += fingerprint.littleEndian
        data += childIndex.littleEndian
        data += chainCode
        data += UInt8(0)
        data += raw
        let checksum = Crypto.sha256sha256(data).prefix(4)
        return Base58.encode(data + checksum)
    }

    func derived(at index: UInt32, hardened: Bool = false) throws -> HDPrivateKey {
        // As we use explicit parameter "hardened", do not allow higher bit set.
        if (0x80000000 & index) != 0 {
            fatalError("invalid child index")
        }

        guard let derivedKey = Crypto.derivedHDKey(hdKey: HDKey(privateKey: raw, publicKey: publicKey().raw, chainCode: chainCode, depth: depth, fingerprint: fingerprint, childIndex: childIndex), at: index, hardened: hardened) else {
            throw DerivationError.derivateionFailed
        }
        return HDPrivateKey(privateKey: derivedKey.privateKey!, chainCode: derivedKey.chainCode, xPrivKey: xPrivKey, xPubKey: xPubKey, depth: derivedKey.depth, fingerprint: derivedKey.fingerprint, childIndex: derivedKey.childIndex)
    }

}

enum DerivationError : Error {
    case derivateionFailed
}
