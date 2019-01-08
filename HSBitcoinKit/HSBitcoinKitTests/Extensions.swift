import XCTest
@testable import HSBitcoinKit

extension XCTestCase {

    func waitForMainQueue(queue: DispatchQueue = DispatchQueue.main) {
        let e = expectation(description: "Wait for Main Queue")
        queue.async { e.fulfill() }
        waitForExpectations(timeout: 2)
    }

}

extension BitcoinKit.KitState: Equatable {

    public static func ==(lhs: BitcoinKit.KitState, rhs: BitcoinKit.KitState) -> Bool {
        switch (lhs, rhs) {
        case (.synced,   .synced): return true
        case let (.syncing(lProgress),   .syncing(rProgress)): return lProgress == rProgress
        case (.notSynced,   .notSynced): return true
        default:
            return false
        }
    }

}

extension SelectorError: Equatable {

    public static func ==(lhs: SelectorError, rhs: SelectorError) -> Bool {
        switch (lhs, rhs) {
        case (.wrongValue, .wrongValue): return true
        case (.emptyOutputs, .emptyOutputs): return true
        case let (.notEnough(lMaxFee),   .notEnough(rMaxFee)): return lMaxFee == rMaxFee
        default:
            return false
        }
    }

}