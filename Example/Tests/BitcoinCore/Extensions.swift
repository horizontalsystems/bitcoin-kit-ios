import XCTest
import Cuckoo
@testable import BitcoinCore

extension XCTestCase {

    func waitForMainQueue(queue: DispatchQueue = DispatchQueue.main) {
        let e = expectation(description: "Wait for Main Queue")
        queue.async { e.fulfill() }
        waitForExpectations(timeout: 2)
    }

}

public func equalErrors(_ lhs: Error?, _ rhs: Error?) -> Bool {
    lhs?.reflectedString == rhs?.reflectedString
}


public extension Error {
    var reflectedString: String {
        // NOTE 1: We can just use the standard reflection for our case
        String(reflecting: self)
    }

    // Same typed Equality
    func isEqual(to: Self) -> Bool {
        self.reflectedString == to.reflectedString
    }

}

extension Block {

    var header: BlockHeader {
        BlockHeader(
                version: version, headerHash: headerHash, previousBlockHeaderHash: previousBlockHash, merkleRoot: merkleRoot,
                timestamp: timestamp, bits: bits, nonce: nonce
        )
    }

    func setHeaderHash(hash: Data) {
        headerHash = hash
    }

}

extension BlockInfo: Equatable {

    public static func ==(lhs: BlockInfo, rhs: BlockInfo) -> Bool {
        lhs.headerHash == rhs.headerHash && lhs.height == rhs.height && lhs.timestamp == rhs.timestamp
    }

}

extension TransactionInfo: Equatable {

    public static func ==(lhs: TransactionInfo, rhs: TransactionInfo) -> Bool {
        lhs.transactionHash == rhs.transactionHash
    }

}

extension PeerAddress: Equatable {

    public static func ==(lhs: PeerAddress, rhs: PeerAddress) -> Bool {
        lhs.ip == rhs.ip
    }

}

extension PublicKey: Equatable {

    public static func ==(lhs: PublicKey, rhs: PublicKey) -> Bool {
        lhs.path == rhs.path
    }

}

extension Checkpoint: Equatable {

    public static func ==(lhs: Checkpoint, rhs: Checkpoint) -> Bool {
        lhs.block == rhs.block
    }

}

extension Block: Equatable {

    public static func ==(lhs: Block, rhs: Block) -> Bool {
        lhs.headerHash == rhs.headerHash
    }

}

extension Transaction: Equatable {

    public static func ==(lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.dataHash == rhs.dataHash
    }

}

extension Input: Equatable {

    public static func ==(lhs: Input, rhs: Input) -> Bool {
        lhs.previousOutputIndex == rhs.previousOutputIndex && lhs.previousOutputTxHash == rhs.previousOutputTxHash
    }

}

extension Output: Equatable {

    public static func ==(lhs: Output, rhs: Output) -> Bool {
        lhs.keyHash == rhs.keyHash && lhs.scriptType == rhs.scriptType && lhs.value == rhs.value && lhs.index == rhs.index
    }

}

extension BlockHeader: Equatable {

    public static func ==(lhs: BlockHeader, rhs: BlockHeader) -> Bool {
        lhs.previousBlockHeaderHash == rhs.previousBlockHeaderHash && lhs.headerHash == rhs.headerHash && lhs.merkleRoot == rhs.merkleRoot
    }

}

extension FullTransaction: Equatable {

    public static func ==(lhs: FullTransaction, rhs: FullTransaction) -> Bool {
        TransactionSerializer.serialize(transaction: lhs) == TransactionSerializer.serialize(transaction: rhs)
    }

}

extension UnspentOutput: Equatable {

    public static func ==(lhs: UnspentOutput, rhs: UnspentOutput) -> Bool {
        lhs.output.value == rhs.output.value
    }

}

extension InputToSign: Equatable {

    public static func ==(lhs: InputToSign, rhs: InputToSign) -> Bool {
        lhs.input == rhs.input && lhs.previousOutputPublicKey == rhs.previousOutputPublicKey
    }

}

func addressMatcher(_ address: Address) -> ParameterMatcher<Address> {
    ParameterMatcher<Address> { address.stringValue == $0.stringValue }
}

func addressMatcher(_ address: Address?) -> ParameterMatcher<Address?> {
    ParameterMatcher<Address?> { tested in
        if let a1 = address, let a2 = tested {
            return addressMatcher(a1).matches(a2)
        } else {
            return address == nil && tested == nil
        }
    }
}

func outputs(withScriptTypes scriptTypes: [ScriptType]) -> [Output] {
    scriptTypes.map { Output(withValue: 0, index: 0, lockingScript: Data(), type: $0) }
}
