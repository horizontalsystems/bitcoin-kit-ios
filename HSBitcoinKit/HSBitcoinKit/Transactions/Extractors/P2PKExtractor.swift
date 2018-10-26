import HSCryptoKit

class P2PKExtractor: IScriptExtractor {
    let minimalKeyLength = 3
    var type: ScriptType { return .p2pk }               // lockingScript: {push-length}{length-byte-public-key 33/65}AC

    func extract(from script: Script, converter: IScriptConverter) throws -> Data? {
        guard script.length >= minimalKeyLength else {
            throw ScriptError.wrongScriptLength
        }
        guard script.chunks.count == 2, script.chunks.last?.opCode == OpCode.checkSig, let result = script.chunks[0].data else {
            throw ScriptError.wrongSequence
        }
        return CryptoKit.sha256ripemd160(result)
    }

}
