class P2PKHExtractor: IScriptExtractor {
    var type: ScriptType { return .p2pkh }      // lockingScript: 76A914{20-byte-key-hash}88AC

    func extract(from script: Script, converter: IScriptConverter) throws -> Data? {
        guard script.length == type.size else {
            throw ScriptError.wrongScriptLength
        }
        let validCodes = OpCode.p2pkhStart + Data(bytes: [0x14]) + OpCode.p2pkhFinish
        try script.validate(opCodes: validCodes)

        guard script.chunks.count > 2, let pushData = script.chunks[2].data else {
            throw ScriptError.wrongSequence
        }
        return pushData
    }

}
