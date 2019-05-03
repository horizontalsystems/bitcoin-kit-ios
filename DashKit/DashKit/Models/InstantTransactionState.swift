import Foundation

class InstantTransactionState: IInstantTransactionState {
    var instantTransactionHashes = [Data]()

    func append(_ hash: Data) {
        instantTransactionHashes.append(hash)
    }

}
