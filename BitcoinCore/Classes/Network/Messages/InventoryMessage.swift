import UIExtensions

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

    var description: String {
        let items = inventoryItems.map { item in
            let objectTypeString: String
            if case .unknown = item.objectType {
                objectTypeString = String(item.type)
            } else {
                objectTypeString = "\(item.objectType)"
            }
            return "[\(objectTypeString): \(item.hash.reversedHex)]" }.joined(separator: ", ")

        return "\(items)"
    }

}
