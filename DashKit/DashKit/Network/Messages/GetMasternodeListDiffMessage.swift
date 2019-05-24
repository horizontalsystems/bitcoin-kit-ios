import BitcoinCore

struct GetMasternodeListDiffMessage: IMessage { // "getmnlistd"

    let baseBlockHash: Data
    let blockHash: Data

}
