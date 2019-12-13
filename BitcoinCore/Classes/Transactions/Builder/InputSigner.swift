import HdWalletKit
import OpenSslKit
import Secp256k1Kit

class InputSigner {
    enum SignError: Error {
        case noPreviousOutput
        case noPreviousOutputAddress
        case noPrivateKey
    }

    let hdWallet: IHDWallet
    let network: INetwork

    init(hdWallet: IHDWallet, network: INetwork) {
        self.hdWallet = hdWallet
        self.network = network
    }

}

extension InputSigner: IInputSigner {

    func sigScriptData(transaction: Transaction, inputsToSign: [InputToSign], outputs: [Output], index: Int) throws -> [Data] {
        let input = inputsToSign[index]
        let previousOutput = input.previousOutput
        let pubKey = input.previousOutputPublicKey
        let publicKey = pubKey.raw

        guard let privateKeyData = try? hdWallet.privateKeyData(account: pubKey.account, index: pubKey.index, external: pubKey.external) else {
            throw SignError.noPrivateKey
        }
        let witness = previousOutput.scriptType == .p2wpkh || previousOutput.scriptType == .p2wpkhSh

        var serializedTransaction = try TransactionSerializer.serializedForSignature(transaction: transaction, inputsToSign: inputsToSign, outputs: outputs, inputIndex: index, forked: witness || network.sigHash.forked)
        serializedTransaction += UInt32(network.sigHash.value)
        let signatureHash = Kit.sha256sha256(serializedTransaction)
        let signature = try Kit.sign(data: signatureHash, privateKey: privateKeyData) + Data([network.sigHash.value])

        switch previousOutput.scriptType {
        case .p2pk: return [signature]
        default: return [signature, publicKey]
        }
    }

}
