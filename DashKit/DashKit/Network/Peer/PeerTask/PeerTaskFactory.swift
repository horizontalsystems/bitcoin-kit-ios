import BitcoinCore

class PeerTaskFactory: IPeerTaskFactory {

    func createRequestMasternodeListDiffTask(baseBlockHash: Data, blockHash: Data) -> PeerTask {
        return RequestMasternodeListDiffTask(baseBlockHash: baseBlockHash, blockHash: blockHash)
    }

}
