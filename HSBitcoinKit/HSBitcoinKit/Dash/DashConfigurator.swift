class DashConfigurator: IBitCoreConfigurator {
    private let bitCoreConfigurator: IBitCoreConfigurator

    let instantSend: IPeerTaskHandler & IInventoryItemsHandler
    let masternodeSyncer: IPeerTaskHandler

    init(transactionSyncer: ITransactionSyncer, masternodeSyncer: IPeerTaskHandler, bitCoreConfigurator: IBitCoreConfigurator) {
        self.bitCoreConfigurator = bitCoreConfigurator
        self.masternodeSyncer = masternodeSyncer
        instantSend = InstantSend(transactionSyncer: transactionSyncer)
    }

    var networkMessageParsers: MessageParsers {
        return bitCoreConfigurator.networkMessageParsers
                .append(element: TransactionLockMessageParser())
                .append(element: TransactionLockVoteMessageParser())
                .append(element: MasternodeListDiffMessageParser())
    }

    var networkMessageSerializers: MessageSerializers {
        return bitCoreConfigurator.networkMessageSerializers
                .append(element: GetMasternodeListDiffMessageSerializer())
    }

    var peerTaskHandler: IPeerTaskHandler? {
        return instantSend.attach(to: masternodeSyncer)
    }

    var inventoryItemsHandler: IInventoryItemsHandler? {
        return instantSend
    }

}
