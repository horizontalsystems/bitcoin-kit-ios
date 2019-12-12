import XCTest
@testable import BitcoinCore
@testable import DashKit

extension XCTestCase {

    func waitForMainQueue(queue: DispatchQueue = DispatchQueue.main) {
        let e = expectation(description: "Wait for Main Queue")
        queue.async { e.fulfill() }
        waitForExpectations(timeout: 2)
    }

}

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

extension InstantTransactionInput: Equatable {

    public static func ==(lhs: InstantTransactionInput, rhs: InstantTransactionInput) -> Bool {
        return lhs.txHash == rhs.txHash &&
                lhs.inputTxHash == rhs.inputTxHash
    }

}

extension UnspentOutput: Equatable {

    public static func ==(lhs: UnspentOutput, rhs: UnspentOutput) -> Bool {
        return lhs.output.value == rhs.output.value
    }

}

extension FullTransaction: Equatable {

    public static func ==(lhs: FullTransaction, rhs: FullTransaction) -> Bool {
        return TransactionSerializer.serialize(transaction: lhs) == TransactionSerializer.serialize(transaction: rhs)
    }

}
