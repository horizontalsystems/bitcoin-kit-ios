import Foundation

class PFromWSHExtractor: PFromWitnessExtractor {
    override var type: ScriptType { return .p2wsh }
}
