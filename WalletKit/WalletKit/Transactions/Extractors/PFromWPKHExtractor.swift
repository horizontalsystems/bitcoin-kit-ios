import Foundation

class PFromWPKHExtractor: PFromWitnessExtractor {
    override var type: ScriptType { return .p2wpkh }
}
