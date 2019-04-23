class ScriptBuilder: IScriptBuilder {

    open func lockingScript(for address: Address) throws -> Data {
        switch address.scriptType {
            case .p2pkh: return OpCode.p2pkhStart + OpCode.push(address.keyHash) + OpCode.p2pkhFinish
            case .p2pk: return OpCode.push(address.keyHash) + OpCode.p2pkFinish
            case .p2sh: return OpCode.p2shStart + OpCode.push(address.keyHash) + OpCode.p2shFinish
            default: throw BitcoinCoreErrors.ScriptBuild.unknownType
        }
    }

}
