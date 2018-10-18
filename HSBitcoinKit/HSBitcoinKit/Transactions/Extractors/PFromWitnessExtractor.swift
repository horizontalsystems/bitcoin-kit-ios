class PFromWitnessExtractor: WitnessExtractor {
    override var type: ScriptType { return .unknown }

    override func extract(from script: Script, converter: IScriptConverter) throws -> Data? {
        let scriptData = try witnessScript(script: script, converter: converter)
        let segWitScript = try converter.decode(data: scriptData)
        _ = try super.extract(from: segWitScript, converter: converter)
        return scriptData
    }

    private func witnessScript(script: Script, converter: IScriptConverter) throws -> Data {
        guard script.length == type.size + 1 else { // in witness sigScript added 1 byte for push data command
            throw ScriptError.wrongScriptLength
        }
        guard script.chunks.count == 1, let scriptData = script.chunks[0].data else {
            throw ScriptError.wrongSequence
        }
        return scriptData
    }

}
