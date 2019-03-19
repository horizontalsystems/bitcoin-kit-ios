class BitCoreConfigurator: IBitCoreConfigurator {
    private let network: INetwork

    init(network: INetwork) {
        self.network = network
    }

    public var networkMessageParsers: MessageParsers {
        return SetOfResponsibility()
                .append(element: AddressMessageParser())
                .append(element: GetDataMessageParser())
                .append(element: InventoryMessageParser())
                .append(element: PingMessageParser())
                .append(element: PongMessageParser())
                .append(element: VerackMessageParser())
                .append(element: VersionMessageParser())
                .append(element: MemPoolMessageParser())
                .append(element: MerkleBlockMessageParser(network: network))
                .append(element: TransactionMessageParser())
    }
    public var networkMessageSerializers: MessageSerializers {
        return SetOfResponsibility()
                .append(element: GetDataMessageSerializer())
                .append(element: GetBlocksMessageSerializer())
                .append(element: InventoryMessageSerializer())
                .append(element: PingMessageSerializer())
                .append(element: PongMessageSerializer())
                .append(element: VerackMessageSerializer())
                .append(element: MempoolMessageSerializer())
                .append(element: VersionMessageSerializer())
                .append(element: TransactionMessageSerializer())
                .append(element: FilterLoadMessageSerializer())
    }
    let peerTaskHandler: IPeerTaskHandler? = nil
    let inventoryItemsHandler: IInventoryItemsHandler? = nil
}
