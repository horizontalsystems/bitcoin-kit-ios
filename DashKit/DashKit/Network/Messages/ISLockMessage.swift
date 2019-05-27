import BitcoinCore

struct ISLockMessage: IMessage {
    let command: String = "islock"

    let inputs: [Outpoint]
    let txHash: Data
    let sign: Data
    let hash: Data
}
