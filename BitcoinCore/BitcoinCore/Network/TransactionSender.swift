import RxSwift

class TransactionSender {
    private let disposeBag = DisposeBag()

    private let transactionSyncer: ITransactionSyncer
    private let syncedReadyPeerManager: ISyncedReadyPeerManager
    private let storage: IStorage
    private let timer: ITransactionSendTimer
    private let logger: Logger?
    private let queue: DispatchQueue

    private let maxRetriesCount: Int
    private let retriesPeriod: Double // seconds

    init(transactionSyncer: ITransactionSyncer, syncedReadyPeerManager: ISyncedReadyPeerManager, storage: IStorage, timer: ITransactionSendTimer,
         logger: Logger? = nil, queue: DispatchQueue = DispatchQueue(label: "Transaction Sender Queue", qos: .background),
         maxRetriesCount: Int = 3, retriesPeriod: Double = 60) {
        self.transactionSyncer = transactionSyncer
        self.syncedReadyPeerManager = syncedReadyPeerManager
        self.storage = storage
        self.timer = timer
        self.logger = logger
        self.queue = queue
        self.maxRetriesCount = maxRetriesCount
        self.retriesPeriod = retriesPeriod
    }

    private func peersToSendTo() throws -> [IPeer] {
        let peers = syncedReadyPeerManager.peers
        guard !peers.isEmpty else {
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

    private func transactionsToSend(from transactions: [FullTransaction]) -> [FullTransaction] {
        transactions.filter { transaction in
            if let sentTransaction = storage.sentTransaction(byHash: transaction.header.dataHash) {
                return sentTransaction.retriesCount < self.maxRetriesCount && sentTransaction.lastSendTime < CACurrentMediaTime() - self.retriesPeriod
            } else {
                return true
            }
        }
    }

    private func transactionSendSuccess(sentTransaction transaction: FullTransaction) {
        guard let sentTransaction = storage.sentTransaction(byHash: transaction.header.dataHash),
              !sentTransaction.sendSuccess else {
            return
        }

        sentTransaction.retriesCount = sentTransaction.retriesCount + 1
        sentTransaction.sendSuccess = true

        if sentTransaction.retriesCount >= maxRetriesCount {
            transactionSyncer.handleInvalid(transactionWithHash: transaction.header.dataHash)
            storage.delete(sentTransaction: sentTransaction)
        } else {
            storage.update(sentTransaction: sentTransaction)
        }
    }

    private func transactionSendStart(transaction: FullTransaction) {
        if let sentTransaction = storage.sentTransaction(byHash: transaction.header.dataHash) {
            sentTransaction.lastSendTime = CACurrentMediaTime()
            sentTransaction.sendSuccess = false
            storage.update(sentTransaction: sentTransaction)
        } else {
            storage.add(sentTransaction: SentTransaction(dataHash: transaction.header.dataHash))
        }
    }

    private func send(transactions: [FullTransaction], toPeers peers: [IPeer]) {
        timer.startIfNotRunning()

        for transaction in transactions {
            transactionSendStart(transaction: transaction)

            for peer in peers {
                peer.add(task: SendTransactionTask(transaction: transaction))
            }
        }
    }

    private func sendPendingTransactions() {
        var transactions = transactionSyncer.newTransactions()

        guard !transactions.isEmpty else {
            timer.stop()
            return
        }

        transactions = transactionsToSend(from: transactions)

        guard !transactions.isEmpty else {
            return
        }

        guard let peers = try? peersToSendTo() else {
            return
        }

        send(transactions: transactions, toPeers: peers)
    }

}

extension TransactionSender: ITransactionSender {

    func verifyCanSend() throws {
        _ = try peersToSendTo()
    }

    func send(pendingTransaction: FullTransaction) throws {
        let peers = try peersToSendTo()

        queue.async {
            self.send(transactions: [pendingTransaction], toPeers: peers)
        }
    }

    func transactionsRelayed(transactions: [FullTransaction]) {
        queue.async {
            for transaction in transactions {
                if let sentTransaction = self.storage.sentTransaction(byHash: transaction.header.dataHash) {
                    self.storage.delete(sentTransaction: sentTransaction)
                }
            }
        }
    }

    func subscribeTo(observable: Observable<Void>) {
        observable.subscribe(onNext: { [weak self] in
                    self?.queue.async {
                        self?.sendPendingTransactions()
                    }
                })
                .disposed(by: disposeBag)
    }

}

extension TransactionSender: ITransactionSendTimerDelegate {

    func timePassed() {
        queue.async {
            self.sendPendingTransactions()
        }
    }

}

extension TransactionSender : IPeerTaskHandler {

    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
        switch task {
        case let task as SendTransactionTask:
            queue.async {
                self.transactionSendSuccess(sentTransaction: task.transaction)
            }
            return true

        default: return false
        }
    }

}
