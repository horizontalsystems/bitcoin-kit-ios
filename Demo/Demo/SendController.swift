import UIKit
import RxSwift
import BitcoinCore

class SendController: UIViewController {
    let feePrefix = "Fee: "
    let disposeBag = DisposeBag()

    @IBOutlet weak var addressTextField: UITextField?
    @IBOutlet weak var amountTextField: UITextField?
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var feeRateTextField: UITextField!

    var priority = FeePriority.medium

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Send"
        feeLabel.text = feePrefix
    }

    @IBAction func amountTextFieldChanged(_ sender: Any) {
        changeFee()
    }

    private func changeFee() {
        guard let address = addressTextField?.text, !address.isEmpty else {
            return
        }

        guard let amountString = amountTextField?.text, let amount = Double(amountString) else {
            return
        }
        let satoshis = Int(amount * 100_000_000)

        let fee = (try? Manager.shared.kit.fee(for: satoshis, toAddress: address, senderPay: true, feeRate: priorityToInt(priority))) ?? 0
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
            try Manager.shared.kit.send(to: address, value: Int(amount * 100000000), feeRate: priorityToInt(priority))

            addressTextField?.text = ""
            amountTextField?.text = ""

            let alert = UIAlertController(title: "Success", message: "\(amount) sent to \(address)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        } catch {
            show(error: "\(error)")
        }
    }

    @IBAction func changePriority(_ sender: UISegmentedControl) {
        feeRateTextField.isHidden = true

        switch sender.selectedSegmentIndex {
        case 0: priority = .lowest
        case 1: priority = .low
        case 2: priority = .medium
        case 3: priority = .high
        case 4: priority = .highest
        case 5:
            feeRateTextField.isHidden = false
            fillPriority(with: feeRateTextField.text)
        default: priority = .medium
        }
        changeFee()
    }

    @IBAction func changeFeeRate(_ sender: UITextField) {
        fillPriority(with: sender.text)
        changeFee()
    }

    func fillPriority(with text: String?) {
        if let feeRate = Int(text ?? "") {
            priority = .custom(feeRate: feeRate)
        } else {
            priority = .medium
        }
    }

    private func show(error: String) {
        let alert = UIAlertController(title: "Send Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

}

public enum FeePriority {
    case lowest
    case low
    case medium
    case high
    case highest
    case custom(feeRate: Int)
}

func priorityToInt(_ priority: FeePriority) -> Int {
    switch priority {
    case .lowest: return 1
    case .low: return 5
    case .medium: return 10
    case .high: return 20
    case .highest: return 30
    case .custom(let feeRate): return feeRate
    }
}