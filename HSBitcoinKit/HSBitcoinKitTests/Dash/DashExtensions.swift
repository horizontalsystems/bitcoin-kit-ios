import XCTest
@testable import HSBitcoinKit

extension MasternodeListDiffMessage: Equatable {

    public static func ==(lhs: MasternodeListDiffMessage, rhs: MasternodeListDiffMessage) -> Bool {
        return lhs.blockHash == rhs.blockHash &&
                lhs.baseBlockHash == rhs.baseBlockHash
    }

}

extension CoinbaseTransaction: Equatable {

    public static func ==(lhs: CoinbaseTransaction, rhs: CoinbaseTransaction) -> Bool {
        return lhs.merkleRootMNList == rhs.merkleRootMNList
    }

}

extension MasternodeListState: Equatable {

    public static func ==(lhs: MasternodeListState, rhs: MasternodeListState) -> Bool {
        return lhs.baseBlockHash == rhs.baseBlockHash
    }

}
