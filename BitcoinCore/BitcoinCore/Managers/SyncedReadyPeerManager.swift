public class SyncedReadyPeerManager {

    private let peerGroup: IPeerGroup
    private let initialBlockDownload: IInitialBlockDownload
    private var listeners = [IPeerSyncAndReadyListeners]()
    private var peerStates = [String: Bool]()

    init(peerGroup: IPeerGroup, initialBlockDownload: IInitialBlockDownload) {
        self.peerGroup = peerGroup
        self.initialBlockDownload = initialBlockDownload
    }

    private func set(state: Bool, to peer: IPeer) {
        let oldState = peerStates[peer.host] ?? false
        peerStates[peer.host] = state

        if oldState != state {
            if state {
                listeners.forEach { $0.onPeerSyncedAndReady(peer: peer) }
            } else {
            }
        }
    }

}

extension SyncedReadyPeerManager: ISyncedReadyPeerManager {

    public var peers: [IPeer] {
        return initialBlockDownload.syncedPeers.filter { self.peerGroup.isReady(peer: $0) }
    }

    public func add(listener: IPeerSyncAndReadyListeners) {
        listeners.append(listener)
    }

}

extension SyncedReadyPeerManager: IPeerGroupListener {

    public func onPeerConnect(peer: IPeer) {
        set(state: false, to: peer)
    }

    public func onPeerDisconnect(peer: IPeer, error: Error?) {
        peerStates.removeValue(forKey: peer.host)
    }

    public func onPeerReady(peer: IPeer) {
        if initialBlockDownload.isSynced(peer: peer) {
            set(state: true, to: peer)
        }
    }

    public func onPeerBusy(peer: IPeer) {
        set(state: false, to: peer)
    }

}

extension SyncedReadyPeerManager: IPeerSyncListener {

    public func onPeerSynced(peer: IPeer) {
        if peerGroup.isReady(peer: peer) {
            set(state: true, to: peer)
        }
    }

    public func onPeerNotSynced(peer: IPeer) {
        set(state: false, to: peer)
    }

}
