//
//  GetDataMessage.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/02/11.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

/// getdata is used in response to inv, to retrieve the content of a specific object,
/// and is usually sent after receiving an inv packet, after filtering known elements.
/// It can be used to retrieve transactions, but only if they are in the memory pool or
/// relay set - arbitrary access to transactions in the chain is not allowed to avoid
/// having clients start to depend on nodes having full transaction indexes (which modern nodes do not).
struct GetDataMessage: IMessage{
    /// Number of inventory entries
    let count: VarInt
    /// Inventory vectors
    let inventoryItems: [InventoryItem]

    init(_ data: Data) {
        let byteStream = ByteStream(data)

        count = byteStream.read(VarInt.self)

        var items = [InventoryItem]()
        for _ in 0..<count.underlyingValue {
            let type = byteStream.read(Int32.self)
            let hash = byteStream.read(Data.self, count: 32)
            let item = InventoryItem(type: type, hash: hash)
            items.append(item)
        }

        inventoryItems = items
    }

    func serialized() -> Data {
        var data = Data()
        data += count.serialized()
        data += inventoryItems.flatMap { $0.serialized() }
        return data
    }

}
