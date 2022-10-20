import RxSwift

class BloomFilterLoader: IBloomFilterManagerDelegate {
    private let disposeBag = DisposeBag()
    private let bloomFilterManager: IBloomFilterManager
    private var peerManager: IPeerManager

    init(bloomFilterManager: IBloomFilterManager, peerManager: IPeerManager) {
        self.bloomFilterManager = bloomFilterManager
        self.peerManager = peerManager
    }

    private func onPeerConnect(peer: IPeer) {
        if let bloomFilter = bloomFilterManager.bloomFilter {
            peer.filterLoad(bloomFilter: bloomFilter)
        }
    }

    func bloomFilterUpdated(bloomFilter: BloomFilter) {
        for peer in peerManager.connected {
            peer.filterLoad(bloomFilter: bloomFilter)
        }
    }

    func subscribeTo(observable: Observable<PeerGroupEvent>) {
        observable.subscribe(
                        onNext: { [weak self] in
                            switch $0 {
                            case .onPeerConnect(let peer): self?.onPeerConnect(peer: peer)
                            default: ()
                            }
                        }
                )
                .disposed(by: disposeBag)
    }

}
