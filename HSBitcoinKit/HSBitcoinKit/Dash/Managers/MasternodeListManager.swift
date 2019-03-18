import Foundation

class MasternodeListManager: IMasternodeListManager {

    var baseBlockHash: Data { return Data(hex: "0000000000000000000000000000000000000000000000000000000000000000")! }

    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) {

    }

}
