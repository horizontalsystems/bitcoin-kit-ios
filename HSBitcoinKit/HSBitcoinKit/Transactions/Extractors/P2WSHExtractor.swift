class P2WSHExtractor: WitnessExtractor {
    override var type: ScriptType { return .p2wsh }                 // lockingScript: 0020{32-byte-script-hash}
}
