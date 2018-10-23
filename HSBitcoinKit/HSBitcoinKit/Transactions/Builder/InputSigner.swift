import HSCryptoKit
import HSHDWalletKit

class InputSigner {
    enum SignError: Error {
        case noPreviousOutput
        case noPreviousOutputAddress
        case noPrivateKey
    }

    let hdWallet: IHDWallet

    init(hdWallet: IHDWallet) {
        self.hdWallet = hdWallet
    }

}

extension InputSigner: IInputSigner {

    func sigScriptData(transaction: Transaction, index: Int) throws -> [Data] {
        let input = transaction.inputs[index]

        guard let prevOutput = input.previousOutput else {
            throw SignError.noPreviousOutput
        }

        guard let pubKey = prevOutput.publicKey else {
            throw SignError.noPreviousOutputAddress
        }

        let publicKey = pubKey.raw

        guard let privateKeyData = try? hdWallet.privateKeyData(index: pubKey.index, external: pubKey.external) else {
            throw SignError.noPrivateKey
        }

        let witness = prevOutput.scriptType == .p2wpkh || prevOutput.scriptType == .p2wpkhSh
        let serializedTransaction = try TransactionSerializer.serializedForSignature(transaction: transaction, inputIndex: index, witness: witness)
        let signatureHash = CryptoKit.sha256sha256(serializedTransaction)
        let signature = try CryptoKit.sign(data: signatureHash, privateKey: privateKeyData) + Data(bytes: [0x01])

        switch prevOutput.scriptType {
        case .p2pk: return [signature]
        default: return [signature, publicKey]
        }
    }

}
