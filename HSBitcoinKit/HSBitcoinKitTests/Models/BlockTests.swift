import Quick
import Nimble
import XCTest
import Cuckoo
import HSCryptoKit
@testable import HSBitcoinKit

class BlockTests: QuickSpec {
    override func spec() {
        describe("#init(withHeader:previousBlock:)") {
            let previousBlock = TestData.checkpointBlock
            let header = TestData.firstBlock.header
            var block: Block!

            beforeEach {
                block = Block(withHeader: header, previousBlock: previousBlock)
            }

            it("sets height to previousBlock + 1") {
                XCTAssertEqual(block.height, previousBlock.height + 1)
            }

            it("sets headerHashReversedHex from serialized header") {
                let headerHashReversedHex = CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: header)).reversedHex
                XCTAssertEqual(block.headerHashReversedHex, headerHashReversedHex)
            }
        }

        describe("#init(withHeader:height:)") {
            let header = TestData.firstBlock.header
            var block: Block!

            beforeEach {
                block = Block(withHeader: header, height: 1)
            }

            it("sets height to given height") {
                XCTAssertEqual(block.height, 1)
            }

            it("sets headerHashReversedHex from serialized header") {
                let headerHashReversedHex = CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: header)).reversedHex
                XCTAssertEqual(block.headerHashReversedHex, headerHashReversedHex)
            }
        }
    }

}
