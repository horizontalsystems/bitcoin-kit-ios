import RxSwift

class BloomFilterLoader: IBloomFilterManagerDelegate {
    private let disposeBag = DisposeBag()
    private let bloomFilterManager: IBloomFilterManager
    private var peers = [IPeer]()

    init(bloomFilterManager: IBloomFilterManager) {
        self.bloomFilterManager = bloomFilterManager
    }

    private func onPeerConnect(peer: IPeer) {
        if let bloomFilter = bloomFilterManager.bloomFilter {
            peer.filterLoad(bloomFilter: bloomFilter)
        }
        peers.append(peer)
    }

    private func onPeerDisconnect(peer: IPeer, error: Error?) {
        if let index = peers.firstIndex(where: { $0.equalTo(peer) }) {
            peers.remove(at: index)
        }
    }

    func bloomFilterUpdated(bloomFilter: BloomFilter) {
        peers.forEach { peer in
            peer.filterLoad(bloomFilter: bloomFilter)
        }
    }

    func subscribeTo(observable: Observable<PeerGroupEvent>) {
        observable.subscribe(
                        onNext: { [weak self] in
                            switch $0 {
                            case .onPeerConnect(let peer): self?.onPeerConnect(peer: peer)
                            case .onPeerDisconnect(let peer, let error): self?.onPeerDisconnect(peer: peer, error: error)
                            default: ()
                            }
                        }
                )
                .disposed(by: disposeBag)
    }

}
