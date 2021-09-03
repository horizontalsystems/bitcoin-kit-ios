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

public struct FullTransaction {

    public let header: Transaction
    public let inputs: [Input]
    public let outputs: [Output]
    public let metaData = TransactionMetadata()

    public init(header: Transaction, inputs: [Input], outputs: [Output]) {
        self.header = header
        self.inputs = inputs
        self.outputs = outputs

        let hash = Kit.sha256sha256(TransactionSerializer.serialize(transaction: self, withoutWitness: true))
        self.header.dataHash = hash
        metaData.transactionHash = hash

        for input in self.inputs {
            input.transactionHash = self.header.dataHash
        }
        for output in self.outputs {
            output.transactionHash = self.header.dataHash
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
