class GetMasternodeListDiffMessageSerializer: IMessageSerializer {
    var id: String { return "getmnlistd" }

    func serialize(message: IMessage) throws -> Data {
        guard let message = message as? GetMasternodeListDiffMessage else {
            throw BitcoinCoreErrors.MessageSerialization.wrongMessageSerializer
        }

        return message.baseBlockHash + message.blockHash
    }

}
