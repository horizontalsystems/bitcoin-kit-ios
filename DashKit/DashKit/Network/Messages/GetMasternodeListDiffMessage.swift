import BitcoinCore

struct GetMasternodeListDiffMessage: IMessage { // "getmnlistd"

    let baseBlockHash: Data
    let blockHash: Data

    var description: String {
        return "\(baseBlockHash) \(blockHash)"
    }

}
