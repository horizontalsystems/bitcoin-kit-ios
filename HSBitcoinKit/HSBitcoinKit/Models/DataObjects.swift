import HSCryptoKit

struct BlockHeader {

    let version: Int
    let headerHash: Data
    let previousBlockHeaderHash: Data
    let merkleRoot: Data
    let timestamp: Int
    let bits: Int
    let nonce: Int

}

struct FullTransaction {

    let header: Transaction
    let inputs: [Input]
    let outputs: [Output]

    init(header: Transaction, inputs: [Input], outputs: [Output]) {
        self.header = header
        self.inputs = inputs
        self.outputs = outputs

        self.header.dataHash = CryptoKit.sha256sha256(TransactionSerializer.serialize(transaction: self, withoutWitness: true))
        self.header.dataHashReversedHex = self.header.dataHash.reversedHex
        for input in self.inputs {
            input.transactionHashReversedHex = self.header.dataHashReversedHex
        }
        for output in self.outputs {
            output.transactionHashReversedHex = self.header.dataHashReversedHex
        }
    }

}

struct InputToSign {

    let input: Input
    let previousOutput: Output
    let previousOutputPublicKey: PublicKey

}

struct InputWithBlock {

    let input: Input
    let block: Block?

}

struct UnspentOutput {

    let output: Output
    let publicKey: PublicKey
    let transaction: Transaction
    let block: Block?

}

struct OutputWithPublicKey {

    let output: Output
    let publicKey: PublicKey

}
