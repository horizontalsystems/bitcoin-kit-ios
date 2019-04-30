import UIKit
import BitcoinCore
import RxSwift

class TransactionsController: UITableViewController {
    let disposeBag = DisposeBag()

    private var transactions = [TransactionInfo]()
    private var transactionsCount = 0
    private var lastBlockInfo: BlockInfo?
    private let limit = 500
    private var loading = false

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Transactions"

        tableView.register(UINib(nibName: String(describing: TransactionCell.self), bundle: Bundle(for: TransactionCell.self)), forCellReuseIdentifier: String(describing: TransactionCell.self))
        tableView.separatorInset = .zero

        loadNext()
        lastBlockInfo = Manager.shared.kit.lastBlockInfo

        Manager.shared.transactionsSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] in
            self?.resetTransactions()
        }).disposed(by: disposeBag)

        Manager.shared.lastBlockInfoSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] info in
            self?.lastBlockInfo = info
        }).disposed(by: disposeBag)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 180
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: String(describing: TransactionCell.self), for: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TransactionCell {
            cell.bind(transaction: transactions[indexPath.row], lastBlockHeight: lastBlockInfo?.height ?? 0, index: transactions.count - indexPath.row)
        }

        if indexPath.row > transactions.count - 3 {
            loadNext()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UIPasteboard.general.setValue(transactions[indexPath.row].transactionHash, forPasteboardType: "public.plain-text")

        let alert = UIAlertController(title: "Success", message: "Transaction Hash copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
        print("hash: \(transactions[indexPath.row].transactionHash)")

        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func loadNext() {
        guard !loading else {
            return
        }

        loading = true

        let from = transactions.last

        let _ = Manager.shared.kit.transactions(fromHash: from?.transactionHash, limit: limit)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .observeOn(MainScheduler.instance)
                .subscribe(onSuccess: { transactions in
                    self.onLoad(transactions: transactions)
        })
    }

    private func onLoad(transactions: [TransactionInfo]) {
        self.transactions.append(contentsOf: transactions)

        tableView.reloadData()

        if transactions.count == limit {
            loading = false
        }
    }

    private func resetTransactions() {
        transactions = []
        loading = false
        loadNext()
    }

}
