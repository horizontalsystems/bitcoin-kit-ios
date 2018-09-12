import Foundation

class P2WSHExtractor: WitnessExtractor {
    override var type: ScriptType { return .p2wsh }
}
