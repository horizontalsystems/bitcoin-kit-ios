import BitcoinCore

struct MasternodeListDiffMessage: IMessage {
    let command: String = "mnlistdiff"

    let baseBlockHash: Data
    let blockHash: Data
    let totalTransactions: UInt32
    let merkleHashesCount: UInt32
    let merkleHashes: [Data]
    let merkleFlagsCount: UInt32
    let merkleFlags: Data
    let cbTx: CoinbaseTransaction
    let deletedMNsCount: UInt32
    let deletedMNs: [Data]
    let mnListCount: UInt32
    let mnList: [Masternode]
}
