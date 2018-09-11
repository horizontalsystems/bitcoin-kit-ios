import Foundation

class PFromWitnessExtractor: ScriptExtractor {
    var type: ScriptType { return .p2wsh }

    func extract(from script: Script, converter: ScriptConverter) throws -> Data {
        guard script.length == type.size else {
            throw ScriptError.wrongScriptLength
        }
        guard script.chunks.count == 1, let scriptData = script.chunks[0].data else {
            throw ScriptError.wrongSequence
        }
        let witnessScript = try converter.decode(data: scriptData)
        guard witnessScript.chunks.count == 2 else {
            throw ScriptError.wrongSequence
        }
        var allowedPushCode = false
        for i in 0..<16 {
            if witnessScript.chunks.first?.opCode == OpCode.push(i).first {
                allowedPushCode = true
                break
            }
        }
        guard allowedPushCode, witnessScript.chunks[1].opCode == 0x14 else {
            throw ScriptError.wrongSequence
        }

        return scriptData
    }

}
