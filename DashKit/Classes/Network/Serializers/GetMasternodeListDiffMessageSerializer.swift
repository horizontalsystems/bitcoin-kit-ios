import BitcoinCore

class GetMasternodeListDiffMessageSerializer: IMessageSerializer {
    var id: String { return "getmnlistd" }

    func serialize(message: IMessage) -> Data? {
        guard let message = message as? GetMasternodeListDiffMessage else {
            return nil
        }

        return message.baseBlockHash + message.blockHash
    }

}
