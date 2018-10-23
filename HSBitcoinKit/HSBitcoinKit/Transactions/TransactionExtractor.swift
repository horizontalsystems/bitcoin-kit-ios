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
            var keyHash: Data?
            for extractor in scriptOutputExtractors {
                do {
                    let script = try scriptConverter.decode(data: output.lockingScript)
                    let payload = try extractor.extract(from: script, converter: scriptConverter)
                    output.scriptType = extractor.type
                    keyHash = payload
                    break
                } catch {
                    //                    print("\(error) can't parse output by this extractor")
                }
            }

            if let keyHash = keyHash, let address = try? addressConverter.convert(keyHash: output.scriptType == .p2wpkh ? output.lockingScript: keyHash, type: output.scriptType) {
                output.keyHash = address.keyHash
                output.address = address.stringValue

                if !address.keyHash.isEmpty, let pubKey = realm.objects(PublicKey.self).filter("keyHash = %@ OR scriptHashForP2WPKH = %@", address.keyHash, address.keyHash).first {
                    if realm.objects(PublicKey.self).filter("scriptHashForP2WPKH = %@", keyHash).first != nil {
                        output.scriptType = .p2wpkhSh
                        output.keyHash = CryptoKit.sha256ripemd160(pubKey.raw)
                    }
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
                        var keyHash: Data?
                        switch extractor.type {
                        case .p2wpkh:
                            keyHash = payload
                        case .p2sh, .p2pkh:
                            keyHash = CryptoKit.sha256ripemd160(payload)
                        default: break
                        }
                        if let keyHash = keyHash, let address = try? addressConverter.convert(keyHash: keyHash, type: extractor.type) {
                            input.keyHash = address.keyHash
                            input.address = address.stringValue
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
