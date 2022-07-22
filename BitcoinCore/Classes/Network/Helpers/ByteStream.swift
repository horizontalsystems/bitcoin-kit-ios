//
//  ByteStream.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/02/11.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

public class ByteStream {
    public let data: Data
    private var offset = 0

    public var availableBytes: Int {
        return data.count - offset
    }

    public var last: UInt8? {
        return data[offset]
    }

    public init(_ data: Data) {
        self.data = data
    }

    public func read<T>(_ type: T.Type) -> T {
        let size = MemoryLayout<T>.size
        let value = data[offset..<(offset + size)].to(type: type)
        offset += size
        return value
    }

    public func read(_ type: VarInt.Type) -> VarInt {
        guard data.count > offset else {
            return VarInt(0)
        }

        let len = data[offset..<(offset + 1)].to(type: UInt8.self)
        let length: UInt64
        switch len {
        case 0...252:
            length = UInt64(len)
            offset += 1
        case 0xfd:
            offset += 1
            length = UInt64(data[offset..<(offset + 2)].to(type: UInt16.self))
            offset += 2
        case 0xfe:
            offset += 1
            length = UInt64(data[offset..<(offset + 4)].to(type: UInt32.self))
            offset += 4
        case 0xff:
            offset += 1
            length = UInt64(data[offset..<(offset + 8)].to(type: UInt64.self))
            offset += 8
        default:
            offset += 1
            length = UInt64(data[offset..<(offset + 8)].to(type: UInt64.self))
            offset += 8
        }
        return VarInt(length)
    }

    public func read(_ type: VarString.Type) -> VarString {
        let length = read(VarInt.self).underlyingValue
        let size = Int(length)
        let value = data[offset..<(offset + size)].to(type: String.self)
        offset += size
        return VarString(value)
    }

    public func read(_ type: Data.Type, count: Int) -> Data {
        let value = data[offset..<(offset + count)]
        offset += count
        return Data(value)
    }
}
