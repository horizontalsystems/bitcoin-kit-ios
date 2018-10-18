import RealmSwift
import HSCryptoKit

enum ScriptError: Error { case wrongScriptLength, wrongSequence }

class TransactionExtractor {
    static let defaultInputExtractors: [IScriptExtractor] = [PFromSHExtractor(), PFromPKHExtractor(), PFromWPKHExtractor(), PFromWSHExtractor()]
    static let defaultOutputExtractors: [IScriptExtractor] = [P2PKHExtractor(), P2PKExtractor(), P2SHExtractor(), P2WPKHExtractor(), P2WSHExtractor(), P2MultiSigExtractor()]

    let scriptInputExtractors: [IScriptExtractor]
    let scriptOutputExtractors: [IScriptExtractor]
    let scriptConverter: IScriptConverter
    let addressConverter: IAddressConverter

    init(scriptInputExtractors: [IScriptExtractor] = TransactionExtractor.defaultInputExtractors, scriptOutputExtractors: [IScriptExtractor] = TransactionExtractor.defaultOutputExtractors,
         scriptConverter: IScriptConverter, addressConverter: IAddressConverter) {
        self.scriptInputExtractors = scriptInputExtractors
        self.scriptOutputExtractors = scriptOutputExtractors
        self.scriptConverter = scriptConverter
        self.addressConverter = addressConverter
    }

}

extension TransactionExtractor: ITransactionExtractor {

    func extract(transaction: Transaction, realm: Realm) {
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

                if !keyHash.isEmpty, let pubKey = realm.objects(PublicKey.self).filter("keyHash = %@", keyHash).first {
                    transaction.isMine = true
                    output.publicKey = pubKey
                }
            }
        }

        transaction.inputs.forEach { input in
            for extractor in scriptInputExtractors {
                do {
                    let script = try scriptConverter.decode(data: input.signatureScript)
                    if let payload = try extractor.extract(from: script, converter: scriptConverter) {
                        switch extractor.type {
                        case .p2sh, .p2pkh, .p2wpkh:
                            let ripemd160 = CryptoKit.sha256ripemd160(payload)
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
