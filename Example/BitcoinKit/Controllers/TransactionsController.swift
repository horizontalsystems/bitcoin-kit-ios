import UIKit
import RxSwift

class TransactionsController: UITableViewController {
    private let disposeBag = DisposeBag()
    private var adapterDisposeBag = DisposeBag()

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

        tableView.estimatedRowHeight = 0

        segmentedControl.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)

        Manager.shared.adapterSignal
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] in
                    self?.updateAdapters()
                })
                .disposed(by: disposeBag)

        updateAdapters()
    }

    private func updateAdapters() {
        segmentedControl.removeAllSegments()

        adapters = Manager.shared.adapters

        adapterDisposeBag = DisposeBag()

        for (index, adapter) in adapters.enumerated() {
            segmentedControl.insertSegment(withTitle: adapter.coinCode, at: index, animated: false)

            adapter.lastBlockObservable
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] in
                        self?.onLastBlockHeightUpdated(index: index)
                    })
                    .disposed(by: adapterDisposeBag)

            adapter.transactionsObservable
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] in
                        self?.onTransactionsUpdated(index: index)
                    })
                    .disposed(by: adapterDisposeBag)
        }

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
        transactions.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CGFloat(TransactionCell.rowHeight(for: transactions[indexPath.row]))
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.dequeueReusableCell(withIdentifier: String(describing: TransactionCell.self), for: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let currentAdapter = currentAdapter, indexPath.row < transactions.count else {
            return
        }

        if let cell = cell as? TransactionCell {
            cell.bind(index: indexPath.row, transaction: transactions[indexPath.row], coinCode: currentAdapter.coinCode, lastBlockHeight: currentAdapter.lastBlockInfo?.height)
        }

        if indexPath.row > transactions.count - 3 {
            loadNext()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let transactionHash = transactions[indexPath.row].transactionHash

        UIPasteboard.general.setValue(transactionHash, forPasteboardType: "public.plain-text")

        print("Transaction Hash: \(transactionHash)")
        print("Raw Transaction: \(currentAdapter?.rawTransaction(transactionHash: transactionHash) ?? "")")

        let alert = UIAlertController(title: "Success", message: "Transaction Hash copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)

        tableView.deselectRow(at: indexPath, animated: true)
    }

    private var currentAdapter: BaseAdapter? {
        guard segmentedControl.selectedSegmentIndex != -1, adapters.count > segmentedControl.selectedSegmentIndex else {
            return nil
        }

        return adapters[segmentedControl.selectedSegmentIndex]
    }

    private func loadNext() {
        guard !loading else {
            return
        }

        loading = true

        let fromUid = transactions.last?.uid

        currentAdapter?.transactionsSingle(fromUid: fromUid, limit: limit)
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
