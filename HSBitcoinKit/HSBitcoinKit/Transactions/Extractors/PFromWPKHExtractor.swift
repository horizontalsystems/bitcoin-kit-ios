class PFromWPKHExtractor: PFromWitnessExtractor {
    override var type: ScriptType { return .p2wpkh }                // scriptSig: 160014{20-byte-key-hash}
}
