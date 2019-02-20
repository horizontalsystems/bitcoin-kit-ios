import Foundation

/// Allows a node to advertise its knowledge of one or more objects. It can be received unsolicited, or in reply to getblocks.
struct InventoryMessage: IMessage {
    /// Number of inventory entries
    let count: VarInt
    /// Inventory vectors
    let inventoryItems: [InventoryItem]

    init(inventoryItems: [InventoryItem]) {
        self.count = VarInt(inventoryItems.count)
        self.inventoryItems = inventoryItems
    }

    init(data: Data) {
        let byteStream = ByteStream(data)

        count = byteStream.read(VarInt.self)

        var inventoryItems = [InventoryItem]()
        var seen = Set<String>()

        for _ in 0..<Int(count.underlyingValue) {
            let item = InventoryItem(byteStream: byteStream)

            guard !seen.contains(item.hash.reversedHex) else {
                continue
            }
            seen.insert(item.hash.reversedHex)
            inventoryItems.append(item)
        }

        self.inventoryItems = inventoryItems
    }

    func serialized() -> Data {
        var data = Data()
        data += count.serialized()
        data += inventoryItems.flatMap {
            $0.serialized()
        }
        return data
    }

}
