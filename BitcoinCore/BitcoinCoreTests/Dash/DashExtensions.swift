import XCTest
@testable import BitcoinCore

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

extension TransactionLockVoteMessage: Equatable {

    public static func ==(lhs: TransactionLockVoteMessage, rhs: TransactionLockVoteMessage) -> Bool {
        return lhs.txHash == rhs.txHash && lhs.outpoint.txHash == rhs.outpoint.txHash
    }

}
