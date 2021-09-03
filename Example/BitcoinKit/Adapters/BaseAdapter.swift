import BitcoinCore
import RxSwift
import Hodler

class BaseAdapter {
    var feeRate: Int { 3 }
    private let coinRate: Decimal = pow(10, 8)

    let name: String
    let coinCode: String

    private let abstractKit: AbstractKit

    let lastBlockSignal = Signal()
    let syncStateSignal = Signal()
    let balanceSignal = Signal()
    let transactionsSignal = Signal()

    init(name: String, coinCode: String, abstractKit: AbstractKit) {
        self.name = name
        self.coinCode = coinCode
        self.abstractKit = abstractKit
    }

    func transactionRecord(fromTransaction transaction: TransactionInfo) -> TransactionRecord {
        var from = [TransactionInputOutput]()
        var to = [TransactionInputOutput]()

        for input in transaction.inputs {
            from.append(TransactionInputOutput(
                    mine: input.mine, address: input.address, value: input.value,
                    changeOutput: false, pluginId: nil, pluginData: nil
            ))
        }

        for output in transaction.outputs {
            guard output.value > 0 else {
                continue
            }

            to.append(TransactionInputOutput(
                    mine: output.mine, address: output.address, value: output.value,
                    changeOutput: output.changeOutput, pluginId: output.pluginId, pluginData: output.pluginData
            ))
        }

        return TransactionRecord(
                uid: transaction.uid,
                transactionHash: transaction.transactionHash,
                transactionIndex: transaction.transactionIndex,
                interTransactionIndex: 0,
                status: TransactionStatus(rawValue: transaction.status.rawValue) ?? TransactionStatus.new,
                type: transaction.type,
                blockHeight: transaction.blockHeight,
                amount: Decimal(transaction.amount) / coinRate,
                fee: transaction.fee.map { Decimal($0) / coinRate },
                date: Date(timeIntervalSince1970: Double(transaction.timestamp)),
                from: from,
                to: to,
                conflictingHash: transaction.conflictingHash
        )
    }

    private func convertToSatoshi(value: Decimal) -> Int {
        let coinValue: Decimal = value * coinRate

        let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        return NSDecimalNumber(decimal: coinValue).rounding(accordingToBehavior: handler).intValue
    }

    func transactionsSingle(fromUid: String?, type: TransactionFilterType? = nil, limit: Int) -> Single<[TransactionRecord]> {
        abstractKit.transactions(fromUid: fromUid, type: type, limit: limit)
                .map { [weak self] transactions -> [TransactionRecord] in
                    transactions.compactMap {
                        self?.transactionRecord(fromTransaction: $0)
                    }
                }
    }

}

extension BaseAdapter {

    var lastBlockObservable: Observable<Void> {
        lastBlockSignal.asObservable().throttle(DispatchTimeInterval.milliseconds(200), scheduler: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
    }

    var syncStateObservable: Observable<Void> {
        syncStateSignal.asObservable().throttle(DispatchTimeInterval.milliseconds(200), scheduler: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
    }

    var balanceObservable: Observable<Void> {
        balanceSignal.asObservable()
    }

    var transactionsObservable: Observable<Void> {
        transactionsSignal.asObservable()
    }

    func start() {
        self.abstractKit.start()
    }

    func refresh() {
        self.abstractKit.start()
    }

    var spendableBalance: Decimal {
        Decimal(abstractKit.balance.spendable) / coinRate
    }

    var unspendableBalance: Decimal {
        Decimal(abstractKit.balance.unspendable) / coinRate
    }

    var lastBlockInfo: BlockInfo? {
        abstractKit.lastBlockInfo
    }

    var syncState: BitcoinCore.KitState {
        abstractKit.syncState
    }

    func receiveAddress() -> String {
        abstractKit.receiveAddress()
    }

    func validate(address: String) throws {
        try abstractKit.validate(address: address)
    }

    func validate(amount: Decimal, address: String?) throws {
        guard amount <= availableBalance(for: address) else {
            throw SendError.insufficientAmount
        }
    }

    func sendSingle(to address: String, amount: Decimal, sortType: TransactionDataSortType, pluginData: [UInt8: IPluginData] = [:]) -> Single<Void> {
        let satoshiAmount = convertToSatoshi(value: amount)

        return Single.create { [unowned self] observer in
            do {
                _ = try self.abstractKit.send(to: address, value: satoshiAmount, feeRate: self.feeRate, sortType: sortType, pluginData: pluginData)
                observer(.success(()))
            } catch {
                observer(.error(error))
            }

            return Disposables.create()
        }
    }

    func availableBalance(for address: String?, pluginData: [UInt8: IPluginData] = [:]) -> Decimal {
        let amount = (try? abstractKit.maxSpendableValue(toAddress: address, feeRate: feeRate, pluginData: pluginData)) ?? 0
        return Decimal(amount) / coinRate
    }

    func maxSpendLimit(pluginData: [UInt8: IPluginData]) -> Int? {
        do {
            return try abstractKit.maxSpendLimit(pluginData: pluginData)
        } catch {
            return 0
        }
    }

    func minSpendableAmount(for address: String?) -> Decimal {
        Decimal(abstractKit.minSpendableValue(toAddress: address)) / coinRate
    }

    func fee(for value: Decimal, address: String?, pluginData: [UInt8: IPluginData] = [:]) -> Decimal {
        do {
            let amount = convertToSatoshi(value: value)
            let fee = try abstractKit.fee(for: amount, toAddress: address, feeRate: feeRate, pluginData: pluginData)
            return Decimal(fee) / coinRate
        } catch {
            return 0
        }
    }

    func printDebugs() {
        print(abstractKit.debugInfo)
        print()
        print(abstractKit.statusInfo)
    }

    func rawTransaction(transactionHash: String) -> String? {
        abstractKit.rawTransaction(transactionHash: transactionHash)
    }

}

enum SendError: Error {
    case insufficientAmount
}
