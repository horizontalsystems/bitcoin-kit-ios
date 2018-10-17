import UIKit
import HSHDWalletKit
import WalletKit

class WordsController: UIViewController {

    @IBOutlet weak var textView: UITextView?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "WalletKit Demo"
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        view.endEditing(true)
    }

    @IBAction func generateNewWords() {
        if let generatedWords = try? Mnemonic.generate() {
            textView?.text = generatedWords.joined(separator: " ")
        }
    }

    @IBAction func login() {
//        let words = textView?.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty } ?? []

        let words = ["fossil", "tone", "series", "matrix", "echo", "snap", "prosper", "grit", "depart", "usual", "bird", "worry"] // regtest with few transactions
//        let words = ["used", "ugly", "meat", "glad", "balance", "divorce", "inner", "artwork", "hire", "invest", "already", "piano"] // mainnet common account
//        let words = ["market", "crowd", "vault", "speak", "enemy", "suggest", "patrol", "foot", "punch", "cycle", "game", "drip"] // regtest with lots of transactions
//        let words = ["rather", "cricket", "moon", "movie", "material", "walk", "settle", "glide", "since", "soldier", "exact", "cabbage"] // don't know

        do {
            try Mnemonic.validate(words: words)

            Manager.shared.login(words: words)

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
