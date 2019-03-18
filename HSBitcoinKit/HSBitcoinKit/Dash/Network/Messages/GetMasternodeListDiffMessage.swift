import Foundation

struct GetMasternodeListDiffMessage: IMessage { // "getmnlistd"
    let baseBlockHash: Data
    let blockHash: Data

    func serialized() -> Data {
        return baseBlockHash + blockHash
    }
}
