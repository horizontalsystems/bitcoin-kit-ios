import UIKit
import BitcoinCore
import RxSwift

class TransactionsController: UITableViewController {
    let disposeBag = DisposeBag()

    var transactions = [TransactionInfo]()
    var lastBlockInfo: BlockInfo?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Transactions"

        tableView.register(UINib(nibName: String(describing: TransactionCell.self), bundle: Bundle(for: TransactionCell.self)), forCellReuseIdentifier: String(describing: TransactionCell.self))

        update()
        lastBlockInfo = Manager.shared.kit.lastBlockInfo

        Manager.shared.transactionsSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] in
            self?.update()
        }).disposed(by: disposeBag)

        Manager.shared.lastBlockInfoSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] info in
            self?.lastBlockInfo = info
            self?.update()
        }).disposed(by: disposeBag)
    }

    private func update() {
        let _ = Manager.shared.kit.transactions().subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background)).observeOn(MainScheduler.instance).subscribe(onSuccess: { transactions in
            self.transactions = transactions
            self.tableView.reloadData()
        })
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: String(describing: TransactionCell.self), for: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TransactionCell {
            cell.bind(transaction: transactions[indexPath.row], lastBlockHeight: lastBlockInfo?.height ?? 0, index: transactions.count - indexPath.row)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < transactions.count else {
            return
        }
        print("hash: \(transactions[indexPath.row].transactionHash)")
    }

}
