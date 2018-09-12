import Foundation

class P2WPKHExtractor: WitnessExtractor {
    override var type: ScriptType { return .p2wpkh }
}
