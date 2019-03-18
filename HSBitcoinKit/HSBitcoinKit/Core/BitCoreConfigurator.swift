class BitCoreConfigurator: IBitCoreConfigurator {
    private let network: INetwork

    init(network: INetwork) {
        self.network = network
    }

    public var networkMessageParsers: SetOfResponsibility<String, Data, IMessage> {
        return SetOfResponsibility()
                .append(id: "addr", element: AddressMessageParser())
                .append(id: "getdata", element: GetDataMessageParser())
                .append(id: "inv", element: InventoryMessageParser())
                .append(id: "ping", element: PingMessageParser())
                .append(id: "pong", element: PongMessageParser())
                .append(id: "verack", element: VerackMessageParser())
                .append(id: "version", element: VersionMessageParser())
                .append(id: "mempool", element: MemPoolMessageParser())
                .append(id: "merkleblock", element: MerkleBlockMessageParser(network: network))
                .append(id: "tx", element: TransactionMessageParser())
    }
    let peerTaskHandler: IPeerTaskHandler? = nil
    let inventoryItemsHandler: IInventoryItemsHandler? = nil
}
