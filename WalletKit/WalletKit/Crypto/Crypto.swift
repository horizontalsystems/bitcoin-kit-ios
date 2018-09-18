import Foundation
import WalletKit.Private
import secp256k1

struct Crypto {
    enum CryptoError: Error {
        case signFailed
        case noEnoughSpace
    }

    static func sha256(_ data: Data) -> Data {
        return _Hash.sha256(data)
    }
    
    static func sha256sha256(_ data: Data) -> Data {
        return sha256(sha256(data))
    }

    static func ripemd160(_ data: Data) -> Data {
        return _Hash.ripemd160(data)
    }

    static func sha256ripemd160(_ data: Data) -> Data {
        return ripemd160(sha256(data))
    }

    static func hmacsha512(data: Data, key: Data) -> Data {
        return _Hash.hmacsha512(data, key: key)
    }

    static func sign(data: Data, privateKey: Data) throws -> Data {
        let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
        defer { secp256k1_context_destroy(ctx) }

        let signature = UnsafeMutablePointer<secp256k1_ecdsa_signature>.allocate(capacity: 1)
        let status = data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
            privateKey.withUnsafeBytes { secp256k1_ecdsa_sign(ctx, signature, ptr, $0, nil, nil) }
        }
        guard status == 1 else { throw CryptoError.signFailed }

        let normalizedsig = UnsafeMutablePointer<secp256k1_ecdsa_signature>.allocate(capacity: 1)
        secp256k1_ecdsa_signature_normalize(ctx, normalizedsig, signature)

        var length: size_t = 128
        var der = Data(count: length)
        guard der.withUnsafeMutableBytes({ return secp256k1_ecdsa_signature_serialize_der(ctx, $0, &length, normalizedsig) }) == 1 else { throw CryptoError.noEnoughSpace }
        der.count = length

        return der
    }

    static func secp256k1_pubkey_create(privateKeyData: Data, compressed: Bool = false) -> Data {
        // Convert Data to byte Array
        let privateKey = privateKeyData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: privateKeyData.count))
        }

        // Create signing context
        let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
        defer { secp256k1_context_destroy(ctx) }

        // Create public key from private key
        var c_publicKey: secp256k1_pubkey = secp256k1_pubkey()
        let result = secp256k1_ec_pubkey_create(
                ctx,
                &c_publicKey,
                UnsafePointer<UInt8>(privateKey)
        )

        // Serialise public key data into byte array (see header docs for secp256k1_pubkey)
        let keySize = compressed ? 33 : 65
        let output = UnsafeMutablePointer<UInt8>.allocate(capacity: keySize)
        let outputLen = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            output.deallocate()
            outputLen.deallocate()
        }
        outputLen.initialize(to: keySize)
        secp256k1_ec_pubkey_serialize(ctx, output, outputLen, &c_publicKey, UInt32(compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED))
        let publicKey = [UInt8](UnsafeBufferPointer(start: output, count: keySize))

        return Data(bytes: publicKey)
    }

}
