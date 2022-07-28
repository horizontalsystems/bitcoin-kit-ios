import OpenSslKit
import UIExtensions

public struct BlockHeader {

    public let version: Int
    public let headerHash: Data
    public let previousBlockHeaderHash: Data
    public let merkleRoot: Data
    public let timestamp: Int
    public let bits: Int
    public let nonce: Int

    public init(version: Int, headerHash: Data, previousBlockHeaderHash: Data, merkleRoot: Data, timestamp: Int, bits: Int, nonce: Int) {
        self.version = version
        self.headerHash = headerHash
        self.previousBlockHeaderHash = previousBlockHeaderHash
        self.merkleRoot = merkleRoot
        self.timestamp = timestamp
        self.bits = bits
        self.nonce = nonce
    }

}

open class FullTransaction {

    public let header: Transaction
    public let inputs: [Input]
    public let outputs: [Output]
    public let metaData = TransactionMetadata()

    public init(header: Transaction, inputs: [Input], outputs: [Output], forceHashUpdate: Bool = true) {
        self.header = header
        self.inputs = inputs
        self.outputs = outputs

        if forceHashUpdate {
            let hash = Kit.sha256sha256(TransactionSerializer.serialize(transaction: self, withoutWitness: true))
            set(hash: hash)
        }
    }

    public func set(hash: Data) {
        header.dataHash = hash
        metaData.transactionHash = hash

        for input in inputs {
            input.transactionHash = header.dataHash
        }
        for output in outputs {
            output.transactionHash = header.dataHash
        }
    }

}

public struct InputToSign {

    let input: Input
    let previousOutput: Output
    let previousOutputPublicKey: PublicKey

}

public struct OutputWithPublicKey {

    let output: Output
    let publicKey: PublicKey
    let spendingInput: Input?
    let spendingBlockHeight: Int?

}

struct InputWithPreviousOutput {

    let input: Input
    let previousOutput: Output?

}

public struct TransactionWithBlock {

    public let transaction: Transaction
    let blockHeight: Int?

}

public struct UnspentOutput {

    public let output: Output
    public let publicKey: PublicKey
    public let transaction: Transaction
    public let blockHeight: Int?

    public init(output: Output, publicKey: PublicKey, transaction: Transaction, blockHeight: Int? = nil) {
        self.output = output
        self.publicKey = publicKey
        self.transaction = transaction
        self.blockHeight = blockHeight
    }

}

public struct FullTransactionForInfo {

    public let transactionWithBlock: TransactionWithBlock
    let inputsWithPreviousOutputs: [InputWithPreviousOutput]
    let outputs: [Output]
    let metaData: TransactionMetadata

    var rawTransaction: String {
        let fullTransaction = FullTransaction(
                header: transactionWithBlock.transaction,
                inputs: inputsWithPreviousOutputs.map { $0.input },
                outputs: outputs
        )

        return TransactionSerializer.serialize(transaction: fullTransaction).hex
    }

}

public struct PublicKeyWithUsedState {

    let publicKey: PublicKey
    let used: Bool

}
