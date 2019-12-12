import Foundation
import OpenSslKit

class CashAddrBech32 {
    private static let base32Alphabets = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

    public static func encode(_ bytes: Data, prefix: String) -> String {
        let payload = convertTo5bit(data: bytes, pad: true)
        let checksum: Data = createChecksum(prefix: prefix, payload: payload) // Data of [UInt5]
        let combined: Data = payload + checksum // Data of [UInt5]
        var base32 = ""
        for b in combined {
            base32 += String(base32Alphabets[String.Index(utf16Offset: Int(b), in: base32Alphabets)])
        }

        return prefix + ":" + base32
    }

    // string : "bitcoincash:qql8zpwglr3q5le9jnjxkmypefaku39dkygsx29fzk"
    public static func decode(_ string: String) -> (prefix: String, data: Data)? {
        // We can't have empty string.
        // Bech32 should be uppercase only / lowercase only.
        guard !string.isEmpty && [string.lowercased(), string.uppercased()].contains(string) else {
            return nil
        }

        let components = string.components(separatedBy: ":")
        // We can only handle string contains both scheme and base32
        guard components.count == 2 else {
            return nil
        }
        let (prefix, base32) = (components[0], components[1])

        var decodedIn5bit: [UInt8] = [UInt8]()
        for c in base32.lowercased() {
            // We can't have characters other than base32 alphabets.
            guard let baseIndex = base32Alphabets.firstIndex(of: c)?.utf16Offset(in: base32Alphabets) else {
                return nil
            }
            decodedIn5bit.append(UInt8(baseIndex))
        }

        // We can't have invalid checksum
        let payload = Data(decodedIn5bit)
        guard verifyChecksum(prefix: prefix, payload: payload) else {
            return nil
        }

        // Drop checksum
        guard let bytes = try? convertFrom5bit(data: payload.dropLast(8)) else {
            return nil
        }
        return (prefix, Data(bytes))
    }

    private static func verifyChecksum(prefix: String, payload: Data) -> Bool {
        return PolyMod(expand(prefix) + payload) == 0
    }

    private static func expand(_ prefix: String) -> Data {
        var ret: Data = Data()
        let buf: [UInt8] = Array(prefix.utf8)
        for b in buf {
            ret += b & 0x1f
        }
        ret += Data(repeating: 0, count: 1)
        return ret
    }

    private static func createChecksum(prefix: String, payload: Data) -> Data {
        let enc: Data = expand(prefix) + payload + Data(repeating: 0, count: 8)
        let mod: UInt64 = PolyMod(enc)
        var ret: Data = Data()
        for i in 0..<8 {
            ret += UInt8((mod >> (5 * (7 - i))) & 0x1f)
        }
        return ret
    }

    private static func PolyMod(_ data: Data) -> UInt64 {
        var c: UInt64 = 1
        for d in data {
            let c0: UInt8 = UInt8(c >> 35)
            c = ((c & 0x07ffffffff) << 5) ^ UInt64(d)
            if c0 & 0x01 != 0 { c ^= 0x98f2bc8e61 }
            if c0 & 0x02 != 0 { c ^= 0x79b76d99e2 }
            if c0 & 0x04 != 0 { c ^= 0xf33e5fb3c4 }
            if c0 & 0x08 != 0 { c ^= 0xae2eabe2a8 }
            if c0 & 0x10 != 0 { c ^= 0x1e4f43e470 }
        }
        return c ^ 1
    }

    private static func convertTo5bit(data: Data, pad: Bool) -> Data {
        var acc = Int()
        var bits = UInt8()
        let maxv: Int = 31 // 31 = 0x1f = 00011111
        var converted: [UInt8] = []
        for d in data {
            acc = (acc << 8) | Int(d)
            bits += 8

            while bits >= 5 {
                bits -= 5
                converted.append(UInt8(acc >> Int(bits) & maxv))
            }
        }

        let lastBits: UInt8 = UInt8(acc << (5 - bits) & maxv)
        if pad && bits > 0 {
            converted.append(lastBits)
        }
        return Data(converted)
    }

    internal static func convertFrom5bit(data: Data) throws -> Data {
        var acc = Int()
        var bits = UInt8()
        let maxv: Int = 255 // 255 = 0xff = 11111111
        var converted: [UInt8] = []
        for d in data {
            guard (d >> 5) == 0 else {
                throw DecodeError.invalidCharacter
            }
            acc = (acc << 5) | Int(d)
            bits += 5

            while bits >= 8 {
                bits -= 8
                converted.append(UInt8(acc >> Int(bits) & maxv))
            }
        }

        let lastBits: UInt8 = UInt8(acc << (8 - bits) & maxv)
        guard bits < 5 && lastBits == 0  else {
            throw DecodeError.invalidBits
        }

        return Data(converted)
    }

    private enum DecodeError: Error {
        case invalidCharacter
        case invalidBits
    }

}
