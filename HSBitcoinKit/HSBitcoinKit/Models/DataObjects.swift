struct BlockHeader {

    let version: Int
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
