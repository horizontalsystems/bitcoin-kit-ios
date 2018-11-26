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
        let realmPublicKeys = realm.objects(PublicKey.self)
        for output in transaction.outputs {
            var payload: Data?
            var validScriptType: ScriptType = .unknown
            for extractor in scriptOutputExtractors {
                do {
                    let script = try scriptConverter.decode(data: output.lockingScript)
                    payload = try extractor.extract(from: script, converter: scriptConverter)
                    validScriptType = extractor.type
                    break
                } catch {
                    btcKitLog.error("\(error) Can't parse output by this extractor")
                }
            }
            guard let addressKeyHash = payload else { continue }

            if let address = try? addressConverter.convert(keyHash: addressKeyHash, type: validScriptType) {
                output.scriptType = validScriptType
                output.address = address.stringValue

                if let keyData = seek(key: address.keyHash, in: realmPublicKeys) {
                    if keyData.wpkhSh {
                        output.scriptType = .p2wpkhSh
                    }
                    output.publicKey = keyData.pubKey
                    output.keyHash = keyData.pubKey.keyHash
                    transaction.isMine = true
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
                    btcKitLog.error("\(error) Can't parse output by this extractor")
                }
            }
        }
    }

    private func seek(key: Data, in results: Results<PublicKey>) -> (pubKey: PublicKey, wpkhSh: Bool)? {
        for result in results {
            if result.keyHash == key {
                return (pubKey: result, wpkhSh: false)
            }
            if result.scriptHashForP2WPKH == key {
                return (pubKey: result, wpkhSh: true)
            }
        }
        return nil
    }

}
