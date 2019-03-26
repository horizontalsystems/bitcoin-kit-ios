class MasternodeListSyncer: IMasternodeListSyncer {
    private var successor: IPeerTaskHandler?

    let peerGroup: IPeerGroup
    let peerTaskFactory: IPeerTaskFactory
    let masternodeListManager: IMasternodeListManager

    init(peerGroup: IPeerGroup, peerTaskFactory: IPeerTaskFactory, masternodeListManager: IMasternodeListManager) {
        self.peerGroup = peerGroup
        self.peerTaskFactory = peerTaskFactory
        self.masternodeListManager = masternodeListManager
    }

    func sync(blockHash: Data) {
        addTask(baseBlockHash: masternodeListManager.baseBlockHash, blockHash: blockHash)
    }

    private func addTask(baseBlockHash: Data, blockHash: Data) {
        let task = peerTaskFactory.createRequestMasternodeListDiffTask(baseBlockHash: baseBlockHash, blockHash: blockHash)
        peerGroup.addTask(peerTask: task)
    }

}

extension MasternodeListSyncer: IPeerTaskHandler {

    @discardableResult func set(successor: IPeerTaskHandler) -> IPeerTaskHandler {
        self.successor = successor
        return self
    }

    @discardableResult func attach(to element: IPeerTaskHandler) -> IPeerTaskHandler {
        return element.set(successor: self)
    }

    func handleCompletedTask(peer: IPeer, task: PeerTask) {
        switch task {
        case let listDiffTask as RequestMasternodeListDiffTask:
            if let message = listDiffTask.masternodeListDiffMessage {
                do {
                    try masternodeListManager.updateList(masternodeListDiffMessage: message)
                } catch {
                    peer.disconnect(error: error)

                    addTask(baseBlockHash: message.baseBlockHash, blockHash: message.blockHash)
                }
            }
        default: successor?.handleCompletedTask(peer: peer, task: task)
        }
    }

}