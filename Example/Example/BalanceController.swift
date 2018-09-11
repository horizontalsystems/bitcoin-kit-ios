import UIKit
import RealmSwift
import RxSwift

class BalanceController: UIViewController {
    let disposeBag = DisposeBag()

    @IBOutlet weak var balanceLabel: UILabel?
    @IBOutlet weak var progressLabel: UILabel?
    @IBOutlet weak var lastBlockLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Balance"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logout))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(start))

        let walletKit = Manager.shared.walletKit!

        update(balance: walletKit.balance)
        update(progress: walletKit.progress)
        update(lastBlockHeight: walletKit.lastBlockHeight)

        Manager.shared.balanceSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] balance in
            self?.update(balance: balance)
        }).disposed(by: disposeBag)

        Manager.shared.progressSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] progress in
            self?.update(progress: progress)
        }).disposed(by: disposeBag)

        Manager.shared.lastBlockHeightSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] height in
            self?.update(lastBlockHeight: height)
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
            try Manager.shared.walletKit.start()
        } catch {
            print("Start Error: \(error)")
        }
    }

    @IBAction func showRealmInfo() {
        Manager.shared.walletKit.showRealmInfo()
    }

    private func update(balance: Int) {
        balanceLabel?.text = "Balance: \(Double(balance) / 100_000_000)"
    }

    private func update(progress: Double) {
        progressLabel?.text = "Sync Progress: \(Int(progress * 100))%"
    }

    private func update(lastBlockHeight: Int) {
        lastBlockLabel?.text = "Last Block: \(lastBlockHeight)"
    }

}
