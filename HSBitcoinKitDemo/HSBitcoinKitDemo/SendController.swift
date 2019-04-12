import UIKit
import RxSwift

class SendController: UIViewController {
    let feePrefix = "Fee: "
    let disposeBag = DisposeBag()
    
    @IBOutlet weak var addressTextField: UITextField?
    @IBOutlet weak var amountTextField: UITextField?
    @IBOutlet weak var feeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Send"
        feeLabel.text = feePrefix
    }
    
    @IBAction func amountTextFieldChanged(_ sender: Any) {
        guard let address = addressTextField?.text, !address.isEmpty else {
            return
        }
        
        guard let amountString = amountTextField?.text, let amount = Double(amountString) else {
            return
        }
        let satoshis = Int(amount * 100_000_000)

        let fee = (try? Manager.shared.bitcoinKit.fee(for: satoshis, toAddress: address, senderPay: true, feeRate: 100)) ?? 0
        feeLabel.text = feePrefix + "\(fee)"
     }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        view.endEditing(true)
    }

    @IBAction func send() {
        guard let address = addressTextField?.text, !address.isEmpty else {
            show(error: "Empty Address")
            return
        }

        guard let amountString = amountTextField?.text, let amount = Double(amountString) else {
            show(error: "Empty or Non Integer Amount")
            return
        }

        do {
            try Manager.shared.bitcoinKit.send(to: address, value: Int(amount * 100000000), feeRate: 100)

            addressTextField?.text = ""
            amountTextField?.text = ""

            let alert = UIAlertController(title: "Success", message: "\(amount) sent to \(address)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        } catch {
            show(error: "\(error)")
        }
    }

    private func show(error: String) {
        let alert = UIAlertController(title: "Send Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

}
