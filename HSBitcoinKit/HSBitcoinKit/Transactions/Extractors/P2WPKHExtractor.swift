class P2WPKHExtractor: WitnessExtractor {
    override var type: ScriptType { return .p2wpkh }            // lockingScript: 0014{20-byte-key-hash}
}
