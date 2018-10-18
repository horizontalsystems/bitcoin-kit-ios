class TransactionCreator {
    enum CreationError: Error {
        case noChangeAddress
        case transactionAlreadyExists
    }

    let feeRate: Int = 60

    private let realmFactory: IRealmFactory
    private let transactionBuilder: ITransactionBuilder
    private let transactionProcessor: ITransactionProcessor
    private let peerGroup: IPeerGroup
    private let addressManager: IAddressManager

    init(realmFactory: IRealmFactory, transactionBuilder: ITransactionBuilder, transactionProcessor: ITransactionProcessor, peerGroup: IPeerGroup, addressManager: IAddressManager) {
        self.realmFactory = realmFactory
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.peerGroup = peerGroup
        self.addressManager = addressManager
    }

}

extension TransactionCreator: ITransactionCreator {

    func create(to address: String, value: Int) throws {
        let realm = realmFactory.realm

        guard let changePubKey = try? addressManager.changePublicKey() else {
            throw CreationError.noChangeAddress
        }

        let transaction = try transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: true, changeScriptType: .p2pkh, changePubKey: changePubKey, toAddress: address)

        if realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first != nil {
            throw CreationError.transactionAlreadyExists
        }

        try realm.write {
            realm.add(transaction)
        }

        transactionProcessor.enqueueRun()
        peerGroup.send(transaction: transaction)
    }

}
