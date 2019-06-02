import UIKit
import RxSwift
import BitcoinCore

class ReceiveController: UIViewController {
    private let disposeBag = DisposeBag()

    @IBOutlet weak var addressLabel: UILabel?
    @IBOutlet weak var addressTypeControl: UISegmentedControl!
    
    private var adapters = [BaseAdapter]()
    private let segmentedControl = UISegmentedControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Receive"

        addressLabel?.layer.cornerRadius = 8
        addressLabel?.clipsToBounds = true

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

        for (index, adapter) in adapters.enumerated() {
            segmentedControl.insertSegment(withTitle: adapter.coinCode, at: index, animated: false)
        }

        navigationItem.titleView = segmentedControl

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.sendActions(for: .valueChanged)

        addressTypeControl.selectedSegmentIndex = 0
        addressTypeControl.isHidden = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        segmentedControl.sendActions(for: .valueChanged)
    }

    func type(segment: Int) -> ScriptType {
        switch segment {
        case 1: return .p2sh
        case 2: return .p2wpkh
        case 3: return .p2wpkhSh
        default: return .p2pkh
        }
    }

    @objc func onSegmentChanged() {
        addressTypeControl.isHidden = segmentedControl.selectedSegmentIndex != 0
        addressTypeControl.selectedSegmentIndex = 0
        updateAddress()

        if let adapter = currentAdapter {
            print(adapter.debugInfo)
        }
    }
    func updateAddress() {
        let segment = addressTypeControl.selectedSegmentIndex
        addressLabel?.text = "  \(currentAdapter?.receiveAddress(for: type(segment: segment)) ?? "")  "
    }

    @IBAction func onAddressTypeChanged(_ sender: Any) {
        updateAddress()
    }
    
    @IBAction func copyToClipboard() {
        if let address = addressLabel?.text?.trimmingCharacters(in: .whitespaces) {
            UIPasteboard.general.setValue(address, forPasteboardType: "public.plain-text")

            let alert = UIAlertController(title: "Success", message: "Address copied", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }

    private var currentAdapter: BaseAdapter? {
        guard segmentedControl.selectedSegmentIndex != -1, adapters.count > segmentedControl.selectedSegmentIndex else {
            return nil
        }

        return adapters[segmentedControl.selectedSegmentIndex]
    }

}
