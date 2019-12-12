import BitcoinCore

class RequestMasternodeListDiffTask: PeerTask {
    let baseBlockHash: Data
    let blockHash: Data

    var masternodeListDiffMessage: MasternodeListDiffMessage? = nil

    init(baseBlockHash: Data, blockHash: Data) {
        self.baseBlockHash = baseBlockHash
        self.blockHash = blockHash
    }

    override func start() {
        let message = GetMasternodeListDiffMessage(baseBlockHash: baseBlockHash, blockHash: blockHash)

        requester?.send(message: message)

        super.start()
    }

    override func handle(message: IMessage) -> Bool {
        if let message = message as? MasternodeListDiffMessage, message.baseBlockHash == baseBlockHash, message.blockHash == blockHash {
            masternodeListDiffMessage = message

            delegate?.handle(completedTask: self)
            return true
        }
        return false
    }

}
