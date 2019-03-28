import XCTest
@testable import HSBitcoinKit

extension XCTestCase {

    func waitForMainQueue(queue: DispatchQueue = DispatchQueue.main) {
        let e = expectation(description: "Wait for Main Queue")
        queue.async { e.fulfill() }
        waitForExpectations(timeout: 2)
    }

}

public func equalErrors(_ lhs: Error?, _ rhs: Error?) -> Bool {
    return lhs?.reflectedString == rhs?.reflectedString
}


public extension Error {
    var reflectedString: String {
        // NOTE 1: We can just use the standard reflection for our case
        return String(reflecting: self)
    }

    // Same typed Equality
    public func isEqual(to: Self) -> Bool {
        return self.reflectedString == to.reflectedString
    }

}

extension Block {

    var header: BlockHeader {
        return BlockHeader(
                version: version, previousBlockHeaderHash: previousBlockHashReversedHex.reversedData!, merkleRoot: merkleRoot,
                timestamp: timestamp, bits: bits, nonce: nonce
        )
    }

    func setHeaderHash(hash: Data) {
        headerHash = hash
        headerHashReversedHex = hash.reversedHex
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

extension BlockInfo: Equatable {

    public static func ==(lhs: BlockInfo, rhs: BlockInfo) -> Bool {
        return lhs.headerHash == rhs.headerHash && lhs.height == rhs.height && lhs.timestamp == rhs.timestamp
    }

}

extension TransactionInfo: Equatable {

    public static func ==(lhs: TransactionInfo, rhs: TransactionInfo) -> Bool {
        return lhs.transactionHash == rhs.transactionHash
    }

}

extension PeerAddress: Equatable {

    public static func ==(lhs: PeerAddress, rhs: PeerAddress) -> Bool {
        return lhs.ip == rhs.ip
    }

}

extension PublicKey: Equatable {

    public static func ==(lhs: PublicKey, rhs: PublicKey) -> Bool {
        return lhs.path == rhs.path
    }

}

extension Block: Equatable {

    public static func ==(lhs: Block, rhs: Block) -> Bool {
        return lhs.headerHash == rhs.headerHash
    }

}

extension Transaction: Equatable {

    public static func ==(lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.dataHashReversedHex == rhs.dataHashReversedHex
    }

}

extension BlockHeader: Equatable {

    public static func ==(lhs: BlockHeader, rhs: BlockHeader) -> Bool {
        return lhs.previousBlockHeaderHash == rhs.previousBlockHeaderHash && lhs.merkleRoot == rhs.merkleRoot
    }

}

extension UnspentOutput: Equatable {

    public static func ==(lhs: UnspentOutput, rhs: UnspentOutput) -> Bool {
        return TransactionOutputSerializer.serialize(output: lhs.output) == TransactionOutputSerializer.serialize(output: rhs.output)
    }

}

extension FullTransaction: Equatable {

    public static func ==(lhs: FullTransaction, rhs: FullTransaction) -> Bool {
        return TransactionSerializer.serialize(transaction: lhs) == TransactionSerializer.serialize(transaction: rhs)
    }

}
