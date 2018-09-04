//
//  AddressMessage.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/02/11.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

/// Provide information on known nodes of the network. Non-advertised nodes should be forgotten after typically 3 hours
struct AddressMessage: IMessage{
    /// Number of address entries (max: 1000)
    let count: VarInt
    /// Address of other nodes on the network. version < 209 will only read the first one.
    /// The uint32_t is a timestamp (see note below).
    let addressList: [NetworkAddress]

    init(_ data: Data) {
        let byteStream = ByteStream(data)

        count = byteStream.read(VarInt.self)

        var aList = [NetworkAddress]()
        for _ in 0..<count.underlyingValue {
            _ = byteStream.read(UInt32.self) // Timestamp
            aList.append(NetworkAddress(byteStream))
        }

        addressList = aList
    }

    func serialized() -> Data {
        return Data()
    }

}
