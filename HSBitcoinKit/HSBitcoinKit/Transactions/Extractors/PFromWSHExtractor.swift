class PFromWSHExtractor: PFromWitnessExtractor {
    override var type: ScriptType { return .p2wsh }                     // scriptSig: 220020{32-byte-script-hash}
}
