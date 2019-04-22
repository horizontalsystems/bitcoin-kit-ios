import BitcoinCore

struct GetMasternodeListDiffMessage: IMessage { // "getmnlistd"
    let command: String = "getmnlistd"

    let baseBlockHash: Data
    let blockHash: Data

}
