import UIKit

class MainController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let balanceNavigation = UINavigationController(rootViewController: BalanceController())
        balanceNavigation.tabBarItem.title = "Balance"

        let transactionsNavigation = UINavigationController(rootViewController: TransactionsController())
        transactionsNavigation.tabBarItem.title = "Transactions"

        let sendNavigation = UINavigationController(rootViewController: SendController())
        sendNavigation.tabBarItem.title = "Send"

        let receiveNavigation = UINavigationController(rootViewController: ReceiveController())
        receiveNavigation.tabBarItem.title = "Receive"

        viewControllers = [balanceNavigation, transactionsNavigation, sendNavigation, receiveNavigation]
    }

}
