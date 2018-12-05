import UIKit
import RealmSwift
import RxSwift
import HSBitcoinKit

class BalanceController: UIViewController {
    let disposeBag = DisposeBag()

    @IBOutlet weak var balanceLabel: UILabel?
    @IBOutlet weak var progressLabel: UILabel?
    @IBOutlet weak var lastBlockLabel: UILabel?

    private lazy var dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM d, yyyy, HH:mm"
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Balance"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logout))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(start))

        let bitcoinKit = Manager.shared.bitcoinKit!

        update(balance: bitcoinKit.balance)

        if let info = bitcoinKit.lastBlockInfo {
            update(lastBlockInfo: info)
        }

        Manager.shared.balanceSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] balance in
            self?.update(balance: balance)
        }).disposed(by: disposeBag)

        Manager.shared.progressSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] progress in
            self?.update(progress: progress)
        }).disposed(by: disposeBag)

        Manager.shared.lastBlockInfoSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] info in
            self?.update(lastBlockInfo: info)
        }).disposed(by: disposeBag)

        Manager.shared.initialSyncErrorSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] error in
            let alert = UIAlertController(title: "Initial Sync Error", message: "\(error)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                self?.start()
            }))
            self?.present(alert, animated: true)
        }).disposed(by: disposeBag)
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
        do {
            try Manager.shared.bitcoinKit.start()
        } catch {
            print("Start Error: \(error)")
        }
    }

    @IBAction func showRealmInfo() {
        print(Manager.shared.bitcoinKit.debugInfo)
    }

    private func update(balance: Int) {
        balanceLabel?.text = "Balance: \(Double(balance) / 100_000_000)"
    }

    private func update(progress: Double) {
        progressLabel?.text = "Sync Progress: \(Int(progress * 100))%"
    }

    private func update(lastBlockInfo info: BlockInfo) {
        var text = "Last Block: \(info.height)"

        if let timestamp = info.timestamp {
            text += "\n\n\(dateFormatter.string(from: Date(timeIntervalSince1970: Double(timestamp))))"
        }

        lastBlockLabel?.text = text
    }

}
