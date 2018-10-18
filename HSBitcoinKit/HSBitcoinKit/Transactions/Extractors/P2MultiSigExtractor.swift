class P2MultiSigExtractor: IScriptExtractor {
    let minimalChunkCount = 4
    var type: ScriptType { return .p2multi }                            // [M][pubKey1][pubKey2]..[pubKeyN][N][CHECKMULTISIG]

    private var pushOpCodes: [UInt8] {
        var codes = [UInt8]()
        for i in 1..<16 {
            codes.append(OpCode.push(i).first ?? 0)
        }
        return codes
    }

    func extract(from script: Script, converter: IScriptConverter) throws -> Data? {
        guard script.chunks.count >= minimalChunkCount else {
            throw ScriptError.wrongSequence
        }
        let pushCountCodes = pushOpCodes
        let n = script.chunks[script.chunks.count - 2].opCode
        guard let m = script.chunks.first?.opCode, pushCountCodes.contains(m), pushCountCodes.contains(n), m <= n else {
            throw ScriptError.wrongSequence
        }
        guard script.chunks.last?.opCode == OpCode.checkMultiSig || script.chunks.last?.opCode == OpCode.checkMultiSigVerify else {
            throw ScriptError.wrongSequence
        }
        return nil
    }

}
