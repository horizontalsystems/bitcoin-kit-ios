import Foundation

class ScriptBuilder {

    enum BuildError: Error { case wrongDataCount, unknownType }

    func lockingScript(for address: Address) throws -> Data {
        var data = [Data]()

        if let address = address as? SegWitAddress {
            data.append(Data([address.version]))
        }
        data.append(address.keyHash)

        switch address.scriptType {
            case .p2pkh: return OpCode.p2pkhStart + OpCode.push(data[0]) + OpCode.p2pkhFinish
            case .p2pk: return OpCode.push(data[0]) + OpCode.p2pkFinish
            case .p2sh: return OpCode.p2shStart + OpCode.push(data[0]) + OpCode.p2shFinish
            case .p2wsh, .p2wpkh: return OpCode.push(Int(data[0][0])) + OpCode.push(data[1])  // Data[0] - version byte, Data[1] - push keyHash
            default: throw BuildError.unknownType
        }
    }

    func unlockingScript(params: [Data]) -> Data {
        return params.reduce(Data()) { $0 + OpCode.push($1) }
    }

}
