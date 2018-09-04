//
//  BlockMessage.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/02/11.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

struct BlockMessage: IMessage{
    let blockHeaderItem: BlockHeader

    /// Number of transaction entries
    let transactionCount: VarInt
    /// Block transactions, in format of "tx" command
    let transactions: [Transaction]

    init(_ data: Data) {
        let byteStream = ByteStream(data)

        blockHeaderItem = BlockHeaderSerializer.deserialize(fromByteStream: byteStream)
        transactionCount = byteStream.read(VarInt.self)

        var txs = [Transaction]()
        for _ in 0..<transactionCount.underlyingValue {
            txs.append(TransactionSerializer.deserialize(byteStream))
        }

        transactions = txs
    }

    func serialized() -> Data {
        var data = Data()
        data += BlockHeaderSerializer.serialize(header: blockHeaderItem)
        data += transactionCount.serialized()
        for transaction in transactions {
            data += TransactionSerializer.serialize(transaction: transaction)
        }
        return data
    }

}
