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
        try witnessScript.validate(opCodes: Data(bytes: [0x00, 0x14]))

        return scriptData
    }

}
