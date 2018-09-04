import UIKit
import RealmSwift
import RxSwift

class BalanceController: UIViewController {
    let disposeBag = DisposeBag()

    @IBOutlet weak var balanceLabel: UILabel?
    @IBOutlet weak var progressLabel: UILabel?

    private var unspentOutputsNotificationToken: NotificationToken?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Balance"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logout))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(start))

        unspentOutputsNotificationToken = Manager.shared.walletKit.unspentOutputsRealmResults.observe { [weak self] _ in
            self?.updateBalance()
        }

        Manager.shared.walletKit.progressSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] progress in
            self?.progressLabel?.text = "Sync Progress: \(Int(progress * 100))%"
        }).disposed(by: disposeBag)
    }

    deinit {
        unspentOutputsNotificationToken?.invalidate()
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

    private func updateBalance() {
        guard Manager.shared.walletKit != nil else {
            return
        }

        var satoshiBalance = 0

        for output in Manager.shared.walletKit.unspentOutputsRealmResults {
            satoshiBalance += output.value
        }

        let balance = Double(satoshiBalance) / 100000000

        balanceLabel?.text = "Balance: \(balance)"
    }

}
