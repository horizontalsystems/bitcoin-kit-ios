import UIKit
import RxSwift
import Hodler
import BitcoinCore

class SendController: UIViewController {
    private let disposeBag = DisposeBag()

    @IBOutlet weak var addressTextField: UITextField?
    @IBOutlet weak var amountTextField: UITextField?
    @IBOutlet weak var coinLabel: UILabel?
    @IBOutlet weak var feeLabel: UILabel?
    @IBOutlet weak var timeLockSwitch: UISwitch?
    @IBOutlet weak var picker: UIPickerView?

    private var timeIntervalStrings = ["Hour", "Month", "Half Year", "Year"]
    private var timeIntervals: [HodlerPlugin.LockTimeInterval] = [.hour, .month, .halfYear, .year]
    private var selectedTimeInterval: HodlerPlugin.LockTimeInterval = .hour

    private var adapters = [BaseAdapter]()
    private let segmentedControl = UISegmentedControl()
    private var timeLockEnabled = false

    override func viewDidLoad() {
        super.viewDidLoad()

        segmentedControl.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)
        picker?.dataSource = self
        picker?.delegate = self

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
    }
    
    private func updateFee() {
        var address: String? = nil
        
        if let addressStr = addressTextField?.text {
            do {
                try currentAdapter?.validate(address: addressStr)
                address = addressStr
            } catch {
            }
        }

        guard let amountString = amountTextField?.text, let amount = Decimal(string: amountString) else {
            feeLabel?.text = "Fee: "
            return
        }
        
        var pluginData = [UInt8: IPluginData]()
        if timeLockEnabled {
            pluginData[HodlerPlugin.id] = HodlerData(lockTimeInterval: self.selectedTimeInterval)
        }
        
        if let fee = currentAdapter?.fee(for: amount, address: address, pluginData: pluginData) {
            feeLabel?.text = "Fee: \(fee.formattedAmount)"
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        view.endEditing(true)
    }
    
    @objc func onSegmentChanged() {
        coinLabel?.text = currentAdapter?.coinCode
        updateFee()
    }
    
    @IBAction func onAddressEditEnded(_ sender: Any) {
        updateFee()
    }
    
    @IBAction func onAmountEditEnded(_ sender: Any) {
        updateFee()
    }
    
    @IBAction func onTimeLockSwitchToggle(_ sender: Any) {
        timeLockEnabled = !timeLockEnabled
        updateFee()
    }
    
    @IBAction func setMaxAmount() {
        var address: String? = nil
        
        if let addressStr = addressTextField?.text {
            do {
                try currentAdapter?.validate(address: addressStr)
                address = addressStr
            } catch {
            }
        }

        var pluginData = [UInt8: IPluginData]()
        if timeLockEnabled {
            pluginData[HodlerPlugin.id] = HodlerData(lockTimeInterval: self.selectedTimeInterval)
        }
        
        if let maxAmount = currentAdapter?.availableBalance(for: address, pluginData: pluginData) {
            amountTextField?.text = "\(maxAmount)"
            onAmountEditEnded(0)
        }
    }
    
    @IBAction func setMinAmount() {
        var address: String? = nil
        
        if let addressStr = addressTextField?.text {
            do {
                try currentAdapter?.validate(address: addressStr)
                address = addressStr
            } catch {
            }
        }

        if let minAmount = currentAdapter?.minSpendableAmount(for: address) {
            amountTextField?.text = "\(minAmount)"
            onAmountEditEnded(0)
        }
    }

    @IBAction func send() {
        guard let address = addressTextField?.text else {
            return
        }

        do {
            try currentAdapter?.validate(address: address)
        } catch {
            show(error: "Invalid address")
            return
        }

        guard let amountString = amountTextField?.text, let amount = Decimal(string: amountString) else {
            show(error: "Invalid amount")
            return
        }
        
        var pluginData = [UInt8: IPluginData]()
        if timeLockEnabled {
            pluginData[HodlerPlugin.id] = HodlerData(lockTimeInterval: self.selectedTimeInterval)
        }

        currentAdapter?.sendSingle(to: address, amount: amount, sortType: .shuffle, pluginData: pluginData)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .observeOn(MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] _ in
                    self?.addressTextField?.text = ""
                    self?.amountTextField?.text = ""

                    self?.showSuccess(address: address, amount: amount)
                }, onError: { [weak self] error in
                    self?.show(error: "Send failed: \(error)")
                })
                .disposed(by: disposeBag)
    }

    private func show(error: String) {
        let alert = UIAlertController(title: "Send Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    private func showSuccess(address: String, amount: Decimal) {
        let alert = UIAlertController(title: "Success", message: "\(amount.formattedAmount) sent to \(address)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    private var currentAdapter: BaseAdapter? {
        guard segmentedControl.selectedSegmentIndex != -1, adapters.count > segmentedControl.selectedSegmentIndex else {
            return nil
        }

        return adapters[segmentedControl.selectedSegmentIndex]
    }

}

extension SendController: UIPickerViewDataSource {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        timeIntervals.count
    }
}

extension SendController: UIPickerViewDelegate {
    public func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        130
    }

    public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        30
    }

    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        timeIntervalStrings[row]
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedTimeInterval = timeIntervals[row]
    }
}
