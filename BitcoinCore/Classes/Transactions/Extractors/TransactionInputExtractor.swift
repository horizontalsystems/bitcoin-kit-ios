import OpenSslKit
import HsToolKit

enum ScriptError: Error { case wrongScriptLength, wrongSequence }

class TransactionInputExtractor {
    private let storage: IStorage
    private let scriptConverter: IScriptConverter
    private let addressConverter: IAddressConverter

    private let logger: Logger?
    
    init(storage: IStorage, scriptConverter: IScriptConverter, addressConverter: IAddressConverter, logger: Logger? = nil) {
        self.storage = storage
        self.scriptConverter = scriptConverter
        self.addressConverter = addressConverter
        
        self.logger = logger
    }

}

extension TransactionInputExtractor: ITransactionExtractor {

    func extract(transaction: FullTransaction) {
        for input in transaction.inputs {
            if let previousOutput = storage.previousOutput(ofInput: input) {
                input.address = previousOutput.address
                input.keyHash = previousOutput.keyHash
                continue
            }
            var payload: Data?
            var validScriptType: ScriptType = ScriptType.unknown
            let signatureScript = input.signatureScript
            let sigScriptCount = signatureScript.count

            if let script = try? scriptConverter.decode(data: signatureScript), // PFromSH input {push-sig}{signature}{push-redeem}{script}
               let chunkData = script.chunks.last?.data,
               let redeemScript = try? scriptConverter.decode(data: chunkData),
               let opCode = redeemScript.chunks.last?.opCode {
                // parse PFromSH transaction input
                var verifyChunkCode: UInt8 = opCode
                if verifyChunkCode == OpCode.endIf,
                   redeemScript.chunks.count > 1,
                   let opCode = redeemScript.chunks.suffix(2).first?.opCode {

                    verifyChunkCode = opCode    // check pre-last chunk
                }
                if OpCode.pFromShCodes.contains(verifyChunkCode) {
                    payload = chunkData                                     //full script
                    validScriptType = .p2sh
                }
            }
            if payload == nil, sigScriptCount >= 106, signatureScript[0] >= 71, signatureScript[0] <= 74 {
                // parse PFromPKH transaction input
                let signatureOffset = signatureScript[0]
                let pubKeyLength = signatureScript[Int(signatureOffset + 1)]

                if (pubKeyLength == 33 || pubKeyLength == 65) && sigScriptCount == signatureOffset + pubKeyLength + 2 {
                    payload = signatureScript.subdata(in: Int(signatureOffset + 2)..<sigScriptCount)    // public key
                    validScriptType = .p2pkh
                }
            }
            if payload == nil, sigScriptCount == ScriptType.p2wpkhSh.size,
               signatureScript[0] == 0x16,
               (signatureScript[1] == 0 || (signatureScript[1] > 0x50 && signatureScript[1] < 0x61)),
               signatureScript[2] == 0x14 {
                // parse PFromWPKH-SH transaction input
                payload = signatureScript.subdata(in: 1..<sigScriptCount)      // 0014{20-byte-key-hash}
                validScriptType = .p2wpkhSh
            }
            if let payload = payload {
                let keyHash = Kit.sha256ripemd160(payload)
                if let address = try? addressConverter.convert(keyHash: keyHash, type: validScriptType) {
                    input.keyHash = address.keyHash
                    input.address = address.stringValue
                }
            }
        }
    }

}
