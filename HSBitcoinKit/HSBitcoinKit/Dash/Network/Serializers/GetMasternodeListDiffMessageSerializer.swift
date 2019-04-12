class GetMasternodeListDiffMessageSerializer: MessageSerializer {
    override var id: String { return "getmnlistd" }

    override func process(_ request: IMessage) -> Data? {
        guard let message = request as? GetMasternodeListDiffMessage else {
            return nil
        }

        return message.baseBlockHash + message.blockHash
    }

}
