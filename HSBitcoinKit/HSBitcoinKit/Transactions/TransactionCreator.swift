class TransactionCreator {
    enum CreationError: Error {
        case transactionAlreadyExists
    }

    let feeRate: Int = 8

    private let realmFactory: IRealmFactory
    private let transactionBuilder: ITransactionBuilder
    private let transactionProcessor: ITransactionProcessor
    private let peerGroup: IPeerGroup

    init(realmFactory: IRealmFactory, transactionBuilder: ITransactionBuilder, transactionProcessor: ITransactionProcessor, peerGroup: IPeerGroup) {
        self.realmFactory = realmFactory
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.peerGroup = peerGroup
    }

}

extension TransactionCreator: ITransactionCreator {

    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool) throws {
        let realm = realmFactory.realm

        let transaction = try transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: senderPay, toAddress: address)

        if realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first != nil {
            throw CreationError.transactionAlreadyExists
        }

        try realm.write {
            realm.add(transaction)
            transactionProcessor.process(transaction: transaction, realm: realm)
        }

        try peerGroup.sendPendingTransactions()
    }

}
