import Foundation

enum ScriptError: Error { case wrongScriptLength, wrongSequence }

protocol ScriptExtractor: class {
    var type: ScriptType { get }
    func extract(from script: Script, converter: ScriptConverter) throws -> Data?
}

class TransactionExtractor {
    static let defaultInputExtractors: [ScriptExtractor] = [PFromSHExtractor(), PFromPKHExtractor(), PFromWPKHExtractor(), PFromWSHExtractor()]
    static let defaultOutputExtractors: [ScriptExtractor] = [P2PKHExtractor(), P2PKExtractor(), P2SHExtractor(), P2WPKHExtractor(), P2WSHExtractor(), P2MultiSigExtractor()]

    let scriptInputExtractors: [ScriptExtractor]
    let scriptOutputExtractors: [ScriptExtractor]
    let scriptConverter: ScriptConverter
    let addressConverter: AddressConverter

    init(scriptInputExtractors: [ScriptExtractor] = TransactionExtractor.defaultInputExtractors, scriptOutputExtractors: [ScriptExtractor] = TransactionExtractor.defaultOutputExtractors,
         scriptConverter: ScriptConverter, addressConverter: AddressConverter) {
        self.scriptInputExtractors = scriptInputExtractors
        self.scriptOutputExtractors = scriptOutputExtractors
        self.scriptConverter = scriptConverter
        self.addressConverter = addressConverter
    }

    func extract(transaction: Transaction) {
        transaction.outputs.forEach { output in
            for extractor in scriptOutputExtractors {
                do {
                    let script = try scriptConverter.decode(data: output.lockingScript)
                    let payload = try extractor.extract(from: script, converter: scriptConverter)
                    output.scriptType = extractor.type
                    output.keyHash = payload
                    break
                } catch {
//                    print("\(error) can't parse output by this extractor")
                }
            }

            if let keyHash = output.keyHash, let address = try? addressConverter.convert(keyHash: keyHash, type: output.scriptType) {
                output.address = address.stringValue
            }
        }

        transaction.inputs.forEach { input in
            for extractor in scriptInputExtractors {
                do {
                    let script = try scriptConverter.decode(data: input.signatureScript)
                    if let payload = try extractor.extract(from: script, converter: scriptConverter) {
                        switch extractor.type {
                            case .p2sh, .p2pkh, .p2wpkh:
                                let ripemd160 = Crypto.sha256ripemd160(payload)
                                input.keyHash = ripemd160
                                input.address = (try? addressConverter.convert(keyHash: ripemd160, type: extractor.type))?.stringValue
                            default: break
                        }
                        break
                    }
                } catch {
//                    print("\(error) can't parse input by this extractor")
                }
            }
        }
    }

}
