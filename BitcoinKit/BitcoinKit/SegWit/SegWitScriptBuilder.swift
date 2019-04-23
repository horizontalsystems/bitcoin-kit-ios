import BitcoinCore

class SegWitScriptBuilder: IScriptBuilder {

    func lockingScript(for address: Address) throws -> Data {
        var data = [Data]()
        guard let segWitAddress = address as? SegWitAddress else {
            throw BitcoinKitErrors.AddressConversion.noSegWitAddress
        }

        data.append(address.keyHash)

        switch address.scriptType {
        case .p2wsh, .p2wpkh: return OpCode.push(Int(segWitAddress.version)) + OpCode.push(address.keyHash)  // Data[0] - version byte, Data[1] - push keyHash
        default: throw BitcoinKitErrors.AddressConversion.noSegWitType          // todo: SegWitAddress can't differ p2wsh or p2wpkh
        }
    }

}
