class DashConfigurator: IBitCoreConfigurator {
    private let bitCoreConfigurator: IBitCoreConfigurator

    let instantSend: IPeerTaskHandler & IInventoryItemsHandler
    let masternodeSyncer: IPeerTaskHandler

    init(transactionSyncer: ITransactionSyncer, masternodeSyncer: IPeerTaskHandler, bitCoreConfigurator: IBitCoreConfigurator) {
        self.bitCoreConfigurator = bitCoreConfigurator
        instantSend = InstantSend(transactionSyncer: transactionSyncer)
        self.masternodeSyncer = masternodeSyncer
    }

    var networkMessageParsers: SetOfResponsibility<String, Data, IMessage> {
        return bitCoreConfigurator.networkMessageParsers
                .append(id: "ix", element: TransactionLockMessageParser())
                .append(id: "txlvote", element: TransactionLockVoteMessageParser())
                .append(id: "mnlistdiff", element: MasternodeListDiffMessageParser())
    }

    var peerTaskHandler: IPeerTaskHandler? {
        return instantSend.attach(to: masternodeSyncer)
    }

    var inventoryItemsHandler: IInventoryItemsHandler? {
        return instantSend
    }

}
