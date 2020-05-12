import UIKit
import RxSwift

class BalanceController: UITableViewController {
    private let disposeBag = DisposeBag()
    private var adapterDisposeBag = DisposeBag()

    private var adapters = [BaseAdapter]()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logout))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(start))

        tableView.register(UINib(nibName: String(describing: BalanceCell.self), bundle: Bundle(for: BalanceCell.self)), forCellReuseIdentifier: String(describing: BalanceCell.self))
        tableView.tableFooterView = UIView()
        tableView.separatorInset = .zero

        tableView.estimatedRowHeight = 0

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
        adapters = Manager.shared.adapters
        tableView.reloadData()

        adapterDisposeBag = DisposeBag()

        for (index, adapter) in adapters.enumerated() {
            Observable.merge([adapter.lastBlockObservable, adapter.syncStateObservable, adapter.balanceObservable])
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] in
                        self?.update(index: index)
                    })
                    .disposed(by: adapterDisposeBag)
        }
    }

    @objc func logout() {
        Manager.shared.logout()

        if let window = UIApplication.shared.keyWindow {
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
                window.rootViewController = UINavigationController(rootViewController: WordsController())
            })
        }
    }

    @objc func start() {
        Manager.shared.adapters.forEach { $0.start() }
        if let button = navigationItem.rightBarButtonItem {
            button.title = "Refresh"
            button.action = #selector(refresh)
        }
    }

    @objc func refresh() {
        Manager.shared.adapters.forEach { $0.refresh() }
    }

    @IBAction func showDebugInfo() {
//        print(Manager.shared.ethereumKit.debugInfo)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return adapters.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 220
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: String(describing: BalanceCell.self), for: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? BalanceCell {
            cell.bind(adapter: adapters[indexPath.row])
        }
    }

    private func update(index: Int) {
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

}
