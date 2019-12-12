/// getdata is used in response to inv, to retrieve the content of a specific object,
/// and is usually sent after receiving an inv packet, after filtering known elements.
/// It can be used to retrieve transactions, but only if they are in the memory pool or
/// relay set - arbitrary access to transactions in the chain is not allowed to avoid
/// having clients start to depend on nodes having full transaction indexes (which modern nodes do not).
public struct GetDataMessage: IMessage {
    /// Number of inventory entries
    let count: VarInt
    /// Inventory vectors
    let inventoryItems: [InventoryItem]

    public init(inventoryItems: [InventoryItem]) {
        self.count = VarInt(inventoryItems.count)
        self.inventoryItems = inventoryItems
    }

    public var description: String {
        return "\(count) items(s)"
    }

}
