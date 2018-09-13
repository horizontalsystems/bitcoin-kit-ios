import Foundation

class ScriptBuilder {

    enum BuildError: Error { case wrongDataCount, unknownType }

    func lockingScript(type: ScriptType, params: [Data]) throws -> Data {
        let paramsCount: Int
        switch type {
            case .p2wsh, .p2wpkh: paramsCount = 2           // [ Version Byte, program ]
            default: paramsCount = 1
        }
        guard (params.count == paramsCount) else {
            throw BuildError.wrongDataCount
        }

        switch type {
                case .p2pkh: return OpCode.p2pkhStart + OpCode.push(params[0]) + OpCode.p2pkhFinish
                case .p2pk: return OpCode.push(params[0]) + OpCode.p2pkFinish
                case .p2sh: return OpCode.p2shStart + OpCode.push(params[0]) + OpCode.p2shFinish
                case .p2wsh, .p2wpkh: return OpCode.push(Int(params[0][0])) + OpCode.push(params[1])  // Data[0] - version byte, Data[1] - push keyHash
            default: throw BuildError.unknownType
        }
    }

    func unlockingScript(params: [Data]) -> Data {
        return params.reduce(Data()) { $0 + OpCode.push($1) }
    }

}
