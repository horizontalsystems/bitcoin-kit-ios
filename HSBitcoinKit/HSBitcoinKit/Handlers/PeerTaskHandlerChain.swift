class PeerTaskHandlerChain: IPeerTaskHandler {
    private var concreteHandlers = [IPeerTaskHandler]()

    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
        for handler in concreteHandlers {
            if handler.handleCompletedTask(peer: peer, task: task) {
                return true
            }
        }
        return false
    }

    func add(handler: IPeerTaskHandler) {
        concreteHandlers.append(handler)
    }

}
