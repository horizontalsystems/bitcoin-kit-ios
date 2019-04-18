class InventoryItemsHandlerChain: IInventoryItemsHandler {
    private var concreteHandlers = [IInventoryItemsHandler]()

    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        concreteHandlers.forEach { handler in
            handler.handleInventoryItems(peer: peer, inventoryItems: inventoryItems)
        }
    }

    func add(handler: IInventoryItemsHandler) {
        concreteHandlers.append(handler)
    }

}
