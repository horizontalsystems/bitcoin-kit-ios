import BitcoinCore
import RxSwift

class BaseAdapter {
    private let feeRate = 10
    private let coinRate: Decimal = pow(10, 8)

    let name: String
    let coinCode: String

    private let abstractKit: AbstractKit

    private let lastBlockSignal = Signal()
    private let syncStateSignal = Signal()
    private let balanceSignal = Signal()
    private let transactionsSignal = Signal()

    init(name: String, coinCode: String, abstractKit: AbstractKit) {
        self.name = name
        self.coinCode = coinCode
        self.abstractKit = abstractKit

        abstractKit.delegate = self
    }

    private func transactionRecord(fromTransaction transaction: TransactionInfo) -> TransactionRecord {
        let fromAddresses = transaction.from.map {
            TransactionAddress(address: $0.address, mine: $0.mine)
        }

        let toAddresses = transaction.to.map {
            TransactionAddress(address: $0.address, mine: $0.mine)
        }

        return TransactionRecord(
                transactionHash: transaction.transactionHash,
                transactionIndex: transaction.transactionIndex,
                amount: Decimal(transaction.amount) / coinRate,
                timestamp: Double(transaction.timestamp),
                from: fromAddresses,
                to: toAddresses,
                blockHeight: transaction.blockHeight
        )
    }

    private func convertToSatoshi(value: Decimal) -> Int {
        let coinValue: Decimal = value * coinRate

        let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        return NSDecimalNumber(decimal: coinValue).rounding(accordingToBehavior: handler).intValue
    }

}

extension BaseAdapter {

    var lastBlockObservable: Observable<Void> {
        return lastBlockSignal.asObservable().throttle(0.2, scheduler: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
    }

    var syncStateObservable: Observable<Void> {
        return syncStateSignal.asObservable().throttle(0.2, scheduler: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
    }

    var balanceObservable: Observable<Void> {
        return balanceSignal.asObservable()
    }

    var transactionsObservable: Observable<Void> {
        return transactionsSignal.asObservable()
    }

    func start() {
        abstractKit.start()
    }

    func clear() {
        try! abstractKit.clear()
    }

    var balance: Decimal {
        return Decimal(abstractKit.balance) / coinRate
    }

    var lastBlockInfo: BlockInfo? {
        return abstractKit.lastBlockInfo
    }

    var syncState: BitcoinCore.KitState {
        return abstractKit.syncState
    }

    var receiveAddress: String {
        return abstractKit.receiveAddress
    }

    func validate(address: String) throws {
        try abstractKit.validate(address: address)
    }

    func validate(amount: Decimal, address: String?) throws {
        guard amount <= availableBalance(for: address) else {
            throw SendError.insufficientAmount
        }
    }

    func sendSingle(to address: String, amount: Decimal) -> Single<Void> {
        let satoshiAmount = convertToSatoshi(value: amount)

        return Single.create { [unowned self] observer in
            do {
                try self.abstractKit.send(to: address, value: satoshiAmount, feeRate: self.feeRate)
                observer(.success(()))
            } catch {
                observer(.error(error))
            }

            return Disposables.create()
        }
    }

    func availableBalance(for address: String?) -> Decimal {
        return max(0, balance - fee(for: balance, address: address))
    }

    func fee(for value: Decimal, address: String?) -> Decimal {
        do {
            let amount = convertToSatoshi(value: value)
            let fee = try abstractKit.fee(for: amount, toAddress: address, senderPay: true, feeRate: feeRate)
            return Decimal(fee) / coinRate
        } catch SelectorError.notEnough(let maxFee) {
            return Decimal(maxFee) / coinRate
        } catch {
            return 0
        }
    }

    func transactionsSingle(fromHash: String?, limit: Int) -> Single<[TransactionRecord]> {
        return abstractKit.transactions(fromHash: fromHash, limit: limit)
                .map { [weak self] transactions -> [TransactionRecord] in
                    return transactions.compactMap {
                        self?.transactionRecord(fromTransaction: $0)
                    }
                }
    }

}

extension BaseAdapter: BitcoinCoreDelegate {

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        transactionsSignal.notify()
    }

    func transactionsDeleted(hashes: [String]) {
        transactionsSignal.notify()
    }

    func balanceUpdated(balance: Int) {
        balanceSignal.notify()
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        lastBlockSignal.notify()
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        syncStateSignal.notify()
    }

}

enum SendError: Error {
    case insufficientAmount
}
