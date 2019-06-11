import RxSwift

class TransactionSender {
    private let disposeBag = DisposeBag()

    var transactionSyncer: ITransactionSyncer
    var peerManager: IPeerManager
    var initialBlockDownload: IInitialBlockDownload
    var syncedReadyPeerManager: ISyncedReadyPeerManager
    var logger: Logger?

    init(transactionSyncer: ITransactionSyncer, peerManager: IPeerManager, initialBlockDownload: IInitialBlockDownload, syncedReadyPeerManager: ISyncedReadyPeerManager, logger: Logger? = nil) {
        self.transactionSyncer = transactionSyncer
        self.peerManager = peerManager
        self.initialBlockDownload = initialBlockDownload
        self.syncedReadyPeerManager = syncedReadyPeerManager
        self.logger = logger
    }

    private func peersToSendTo() throws -> [IPeer] {
        guard peerManager.connected().count > 0 else {
            throw BitcoinCoreErrors.TransactionSendError.noConnectedPeers
        }

        guard initialBlockDownload.allPeersSynced else {
            throw BitcoinCoreErrors.TransactionSendError.peersNotSynced
        }

        let peers = syncedReadyPeerManager.peers
        guard peers.count > 0 else {
            throw BitcoinCoreErrors.TransactionSendError.peersNotSynced
        }

        let peersToSendTo: [IPeer]

        if peers.count == 1 {
            peersToSendTo = peers
        } else {
            peersToSendTo = Array(peers.prefix(peers.count / 2))
        }

        return peersToSendTo
    }

    private func send(transactions: [FullTransaction], toPeers peers: [IPeer]) {
        for peer in peers {
            for transaction in transactions {
                peer.add(task: SendTransactionTask(transaction: transaction))
            }
        }
    }

    private func onPeerSyncedAndReady(peer: IPeer) {
        guard peerManager.connected().count == initialBlockDownload.syncedPeers.count else {
            return
        }

        let transactions = transactionSyncer.pendingTransactions()

        guard transactions.count > 0, let peers = try? peersToSendTo() else {
            return
        }

        send(transactions: transactionSyncer.pendingTransactions(), toPeers: peers)
    }

}

extension TransactionSender: ITransactionSender {

    func verifyCanSend() throws {
        _ = try peersToSendTo()
    }

    func send(pendingTransaction: FullTransaction) throws {
        let peers = try peersToSendTo()

        send(transactions: [pendingTransaction], toPeers: peers)
    }

    func subscribeTo(observable: Observable<IPeer>) {
        observable.subscribe(onNext: { [weak self] in
                    self?.onPeerSyncedAndReady(peer: $0)
                })
                .disposed(by: disposeBag)
    }

}
