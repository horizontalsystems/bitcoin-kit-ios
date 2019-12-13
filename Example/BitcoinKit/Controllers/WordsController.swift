import UIKit
import HdWalletKit

class WordsController: UIViewController {

    @IBOutlet weak var textView: UITextView?
    @IBOutlet weak var wordListControl: UISegmentedControl!
    @IBOutlet weak var syncModeListControl: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "BitcoinKit Demo"

        textView?.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView?.layer.cornerRadius = 8

        textView?.text = Configuration.shared.defaultWords[wordListControl.selectedSegmentIndex]
        updateWordListControl()
    }

    func updateWordListControl() {
        let accountCount = Configuration.shared.defaultWords.count
        guard accountCount > 1 else {
            wordListControl.isHidden = true
            return
        }
        wordListControl.removeAllSegments()
        for index in 0..<accountCount {
            wordListControl.insertSegment(withTitle: "\(accountCount - index)", at: 0, animated: false)
        }
        wordListControl.selectedSegmentIndex = 0
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        view.endEditing(true)
    }
    @IBAction func changeWordList(_ sender: Any) {
        textView?.text = Configuration.shared.defaultWords[wordListControl.selectedSegmentIndex]
    }

    @IBAction func generateNewWords() {
        if let generatedWords = try? Mnemonic.generate() {
            textView?.text = generatedWords.joined(separator: " ")
            wordListControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }
    }

    @IBAction func login() {
        let words = textView?.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty } ?? []

        do {
            try Mnemonic.validate(words: words)

            Manager.shared.login(words: words, syncModeIndex: syncModeListControl.selectedSegmentIndex)

            if let window = UIApplication.shared.keyWindow {
                UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
                    window.rootViewController = MainController()
                })
            }
        } catch {
            let alert = UIAlertController(title: "Validation Error", message: "\(error)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }

}
