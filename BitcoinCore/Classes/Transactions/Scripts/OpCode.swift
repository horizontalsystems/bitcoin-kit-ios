import Foundation
import OpenSslKit

public class OpCode {
    public static let p2pkhStart = Data([OpCode.dup, OpCode.hash160])
    public static let p2pkhFinish = Data([OpCode.equalVerify, OpCode.checkSig])

    public static let p2pkFinish = Data([OpCode.checkSig])

    public static let p2shStart = Data([OpCode.hash160])
    public static let p2shFinish = Data([OpCode.equal])

    public static let pFromShCodes = [checkSig, checkSigVerify, checkMultiSig, checkMultiSigVerify]

    public static let pushData1: UInt8 = 0x4c
    public static let pushData2: UInt8 = 0x4d
    public static let pushData4: UInt8 = 0x4e
    public static let drop: UInt8 = 0x75
    public static let dup: UInt8 = 0x76
    public static let sha256: UInt8 = 0xA8
    public static let hash160: UInt8 = 0xA9
    public static let size: UInt8 = 0x82
    public static let equal: UInt8 = 0x87
    public static let equalVerify: UInt8 = 0x88
    public static let checkSig: UInt8 = 0xAC
    public static let checkSigVerify: UInt8 = 0xAD
    public static let checkMultiSig: UInt8 = 0xAE
    public static let checkMultiSigVerify: UInt8 = 0xAF
    public static let checkLockTimeVerify: UInt8 = 0xB1
    public static let checkSequenceVerify: UInt8 = 0xB2
    public static let _if: UInt8 = 0x63
    public static let _else: UInt8 = 0x67
    public static let endIf: UInt8 = 0x68
    public static let op_return: UInt8 = 0x6a

    public static func value(fromPush code: UInt8) -> UInt8? {
        if code == 0 {
            return 0
        }

        let represent = Int(code) - 0x50
        if represent >= 1, represent <= 16 {
            return UInt8(represent)
        }
        return nil
    }

    public static func push(_ value: Int) -> Data {
        guard value != 0 else {
            return Data([0])
        }
        guard value <= 16 else {
            return Data()
        }
        return Data([UInt8(value + 0x50)])
    }

    public static func push(_ data: Data) -> Data {
        let length = data.count
        var bytes = Data()

        switch length {
        case 0x00...0x4b: bytes = Data([UInt8(length)])
        case 0x4c...0xff: bytes = Data([OpCode.pushData1]) + UInt8(length).littleEndian
        case 0x0100...0xffff: bytes = Data([OpCode.pushData2]) + UInt16(length).littleEndian
        case 0x10000...0xffffffff: bytes = Data([OpCode.pushData4]) + UInt32(length).littleEndian
        default: return data
        }

        return bytes + data
    }

    public static func scriptWPKH(_ data: Data, versionByte: Int = 0) -> Data {
        return OpCode.push(versionByte) + OpCode.push(data)
    }

}
