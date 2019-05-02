import UIKit
import RxSwift

class TransactionsController: UITableViewController {
    private let disposeBag = DisposeBag()

    private var adapters = [BaseAdapter]()
    private var transactions = [TransactionRecord]()

    private let segmentedControl = UISegmentedControl()

    private let limit = 20
    private var loading = false

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UINib(nibName: String(describing: TransactionCell.self), bundle: Bundle(for: TransactionCell.self)), forCellReuseIdentifier: String(describing: TransactionCell.self))
        tableView.tableFooterView = UIView()
        tableView.separatorInset = .zero

        adapters.append(contentsOf: Manager.shared.adapters)

        for (index, adapter) in adapters.enumerated() {
            segmentedControl.insertSegment(withTitle: adapter.coinCode, at: index, animated: false)

            adapter.lastBlockObservable
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] in
                        self?.onLastBlockHeightUpdated(index: index)
                    })
                    .disposed(by: disposeBag)

            adapter.transactionsObservable
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] in
                        self?.onTransactionsUpdated(index: index)
                    })
                    .disposed(by: disposeBag)
        }

        segmentedControl.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)

        navigationItem.titleView = segmentedControl

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.sendActions(for: .valueChanged)
    }

    @objc func onSegmentChanged() {
        transactions = []
        loading = false
        loadNext()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 220
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: String(describing: TransactionCell.self), for: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TransactionCell {
            cell.bind(transaction: transactions[indexPath.row], coinCode: currentAdapter.coinCode, lastBlockHeight: currentAdapter.lastBlockInfo?.height)
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

        tableView.deselectRow(at: indexPath, animated: true)
    }

    private var currentAdapter: BaseAdapter {
        return adapters[segmentedControl.selectedSegmentIndex]
    }

    private func loadNext() {
        guard !loading else {
            return
        }

        loading = true

        let fromHash = transactions.last?.transactionHash

        currentAdapter.transactionsSingle(fromHash: fromHash, limit: limit)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .observeOn(MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] transactions in
                    self?.onLoad(transactions: transactions)
                })
                .disposed(by: disposeBag)
    }

    private func onLoad(transactions: [TransactionRecord]) {
        self.transactions.append(contentsOf: transactions)

        tableView.reloadData()

        if transactions.count == limit {
            loading = false
        }
    }

    private func onLastBlockHeightUpdated(index: Int) {
        if index == segmentedControl.selectedSegmentIndex {
            tableView.reloadData()
        }
    }

    private func onTransactionsUpdated(index: Int) {
        if index == segmentedControl.selectedSegmentIndex {
            onSegmentChanged()
        }
    }

}
