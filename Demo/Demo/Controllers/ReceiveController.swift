import UIKit

class ReceiveController: UIViewController {

    @IBOutlet weak var addressLabel: UILabel?

    private var adapters = [BaseAdapter]()
    private let segmentedControl = UISegmentedControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Receive"

        addressLabel?.layer.cornerRadius = 8
        addressLabel?.clipsToBounds = true

        adapters.append(contentsOf: Manager.shared.adapters)

        for (index, adapter) in adapters.enumerated() {
            segmentedControl.insertSegment(withTitle: adapter.coinCode, at: index, animated: false)
        }

        segmentedControl.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)

        navigationItem.titleView = segmentedControl

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.sendActions(for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        segmentedControl.sendActions(for: .valueChanged)
    }

    @objc func onSegmentChanged() {
        addressLabel?.text = "  \(currentAdapter.receiveAddress)  "
    }

    @IBAction func copyToClipboard() {
        if let address = addressLabel?.text {
            UIPasteboard.general.setValue(address, forPasteboardType: "public.plain-text")

            let alert = UIAlertController(title: "Success", message: "Address copied", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }

    private var currentAdapter: BaseAdapter {
        return adapters[segmentedControl.selectedSegmentIndex]
    }

}
