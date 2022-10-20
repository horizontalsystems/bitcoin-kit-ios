import BigInt

public class DifficultyEncoder: IDifficultyEncoder {

    /**
     * <p>The "compact" format is a representation of a whole number N using an unsigned 32 bit number similar to a
     * floating point format. The most significant 8 bits are the unsigned exponent of base 256. This exponent can
     * be thought of as "number of bytes of N". The lower 23 bits are the mantissa. Bit number 24 (0x800000) represents
     * the sign of N. Therefore, N = (-1^sign) * mantissa * 256^(exponent-3).</p>
     *6297032256704216602113604774641040999057504088462746055606272
     * <p>Satoshi's original implementation used BN_bn2mpi() and BN_mpi2bn(). MPI uses the most significant bit of the
     * first byte as sign. Thus 0x1234560000 is compact 0x05123456 and 0xc0de000000 is compact 0x0600c0de. Compact
     * 0x05c0de00 would be -0x40de000000.</p>
     *
     * <p>Bitcoin only uses this "compact" format for encoding difficulty targets, which are unsigned 256bit quantities.
     * Thus, all the complexities of the sign bit and using base 256 are probably an implementation accident.</p>
 */
    public init() {}

    public func compactFrom(hash: Data) -> Int {
        var hashSize = hash.count - 1
        while hashSize >= 0, hash[hashSize] == 0 {
            hashSize -= 1
        }
        hashSize += 1
        hashSize = max(hashSize, 3)         // if difficulty very stronger we must show bits as minimum 3 bytes (ex. 0x030000xx)

        var firstSignificant = 0

        let isBigFirstSignificant = hash[hashSize - 1] > 0x7f                   // if first byte > 0x7f we need add 0x00 as first byte and increase hashSize
        let ignoreByte = hashSize == hash.count && isBigFirstSignificant        // if difficulty very simple and last byte > 0x7f we must make length = 33 and add 0x00)

        if isBigFirstSignificant {
            hashSize += 1
        }
        if !ignoreByte {
            firstSignificant = Int(hash[hashSize - 1]) << 16
        }

        return hashSize << 24 + firstSignificant + Int(hash[hashSize - 2]) << 8 + Int(hash[hashSize - 3])
    }

    public func decodeCompact(bits: Int) -> BigInt {
        let size = (bits >> 24) & 0xFF

        let negativeSign = (bits >> 23) & 0x0001 == 1

        let significantBytes = bits & 0x007FFFFF
        var bigInt = BigInt(significantBytes) * (negativeSign ? -1 : 1)
        if size > 3 {
            bigInt = bigInt << ((size - 3) * 8)
        }

        return bigInt
    }

    public func encodeCompact(from bigInt: BigInt) -> Int {
        var result: Int = 0

        // make unsigned big int for get array of bytes
        let data = bigInt.magnitude.serialize()
        guard !data.isEmpty else {
            return 0
        }

        var byteArray = data.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: data.count))
        }

        if let firstByte = byteArray.first, firstByte > 0x7f {
            // add leading zero if first byte value use more 7 bits
            byteArray.insert(0x00, at: 0)
        }

        // add significant bytes to result
        for (i, byte) in byteArray.enumerated() {
            result = result << 8 + Int(byte)
            if i >= 2 {
                break
            }
        }

        // add counter to result
        result += byteArray.count << 24


        // add sign for first byte
        if bigInt.sign == .minus {
            result |= 0x800000
        }

        return result
    }

}
