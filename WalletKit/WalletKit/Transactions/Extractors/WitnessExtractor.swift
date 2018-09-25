import Foundation

class WitnessExtractor: ScriptExtractor {
    var type: ScriptType { return .unknown }

    func extract(from script: Script, converter: ScriptConverter) throws -> Data? {
        let witnessKeyHash = try keyHash(from: script)

        return witnessKeyHash
    }

    private func keyHash(from script: Script) throws -> Data {
        guard script.length == type.size else {
            throw ScriptError.wrongScriptLength
        }
        guard script.chunks.count == 2 else {
            throw ScriptError.wrongSequence
        }
        var allowedPushCode = false
        for i in 0..<16 {
            if script.chunks.first?.opCode == OpCode.push(i).first {
                allowedPushCode = true
                break
            }
        }

        guard allowedPushCode, script.chunks[1].opCode == type.keyLength, let keyHash = script.chunks[1].data else {
            throw ScriptError.wrongSequence
        }
        return keyHash
    }

}
