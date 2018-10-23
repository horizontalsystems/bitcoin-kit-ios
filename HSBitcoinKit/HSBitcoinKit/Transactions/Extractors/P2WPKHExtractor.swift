class P2WPKHExtractor: WitnessExtractor {
    override var type: ScriptType { return .p2wpkh }            // lockingScript: 0014{20-byte-key-hash}

    override func extract(from script: Script, converter: IScriptConverter) throws -> Data? {
        if try super.extract(from: script, converter: converter) != nil {
            return script.scriptData
        }
        return nil
    }

}
