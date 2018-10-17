import UIKit

class ReceiveController: UIViewController {

    @IBOutlet weak var addressLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Receive"

        addressLabel?.text = Manager.shared.bitcoinKit.receiveAddress
    }

    @IBAction func copyToClipboard() {
        if let address = addressLabel?.text {
            UIPasteboard.general.setValue(address, forPasteboardType: "public.plain-text")

            let alert = UIAlertController(title: "Success", message: "Address copied", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }

}
