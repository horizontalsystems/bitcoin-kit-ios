import UIKit
import WalletKit
import RealmSwift

class TransactionsController: UITableViewController {

    private var transactionsNotificationToken: NotificationToken?

    var records = [TransactionRecord]()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Transactions"

        tableView.register(UINib(nibName: String(describing: TransactionCell.self), bundle: Bundle(for: TransactionCell.self)), forCellReuseIdentifier: String(describing: TransactionCell.self))

        transactionsNotificationToken = Manager.shared.walletKit.transactionsRealmResults.observe { [weak self] _ in
            self?.update()
        }
    }

    deinit {
        transactionsNotificationToken?.invalidate()
    }

    private func update() {
        guard Manager.shared.walletKit != nil else {
            return
        }

        records = []

        for transaction in Manager.shared.walletKit.transactionsRealmResults {
            records.append(transactionRecord(fromTransaction: transaction))
        }

        tableView.reloadData()
    }

    private func transactionRecord(fromTransaction transaction: Transaction) -> TransactionRecord {
        var totalInput: Int = 0
        var totalOutput: Int = 0
        var totalMineInput: Int = 0
        var totalMineOutput: Int = 0
        var fromAddresses = [TransactionAddress]()
        var toAddresses = [TransactionAddress]()

        for input in transaction.inputs {
            if let previousOutput = input.previousOutput {
                totalInput += previousOutput.value

                if previousOutput.publicKey != nil {
                    totalMineInput += previousOutput.value
                }
            }
            let mine = input.previousOutput?.publicKey == nil
            if let address = input.address {
                fromAddresses.append(TransactionAddress(address: address, mine: mine))
            }
        }

        for output in transaction.outputs {
            totalOutput += output.value

            var mine = false
            if output.publicKey != nil {
                totalMineOutput += output.value
                mine = true
            }
            if let address = output.address {
                toAddresses.append(TransactionAddress(address: address, mine: mine))
            }
        }

        let amount = totalMineOutput - totalMineInput
        let fee = totalInput - totalOutput

        return TransactionRecord(
                transactionHash: transaction.reversedHashHex,
                from: fromAddresses,
                to: toAddresses,
                amount: Double(amount) / 100000000,
                fee: Double(fee) / 100000000,
                blockHeight: transaction.block?.height,
                timestamp: transaction.block?.header?.timestamp
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return records.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: String(describing: TransactionCell.self), for: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TransactionCell {
            cell.bind(record: records[indexPath.row])
        }
    }

}
