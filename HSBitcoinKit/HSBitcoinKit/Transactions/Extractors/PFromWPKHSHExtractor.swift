class PFromWPKHSHExtractor: PFromWitnessExtractor {
    override var type: ScriptType { return .p2wpkhSh }                // scriptSig: 160014{20-byte-key-hash}

    override func extract(from data: Data, converter: IScriptConverter) throws -> Data? {
        let dataCount = data.count
        guard dataCount == type.size else {
            throw ScriptError.wrongScriptLength
        }
        guard data[0] == 0x16 && (data[1] == 0 || (data[1] > 0x50 && data[1] < 0x61)),
              data[2] == 0x14 else {
            throw ScriptError.wrongSequence
        }
        return data.subdata(in: 1..<dataCount)      // 0014{20-byte-key-hash}
    }

}
