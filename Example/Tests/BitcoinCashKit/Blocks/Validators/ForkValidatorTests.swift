import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore
@testable import BitcoinCashKit

class ForkValidatorTests: QuickSpec {

    override func spec() {
        let mockBlockValidator = MockIBitcoinCashBlockValidator()
        let blockHash = Data(repeating: 0x01, count: 2)
        let validator = ForkValidator(concreteValidator: mockBlockValidator, forkHeight: 1000, expectedBlockHash: blockHash)

        let block = Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: blockHash,
                        previousBlockHeaderHash: Data(),
                        merkleRoot: Data(),
                        timestamp: 1534820198,
                        bits: 402796414,
                        nonce: 1748283264
                ),
                height: 1000)
        let prevBlock = Block(
                    withHeader: BlockHeader(
                    version: 536870912,
                    headerHash: Data(repeating: 0x02, count: 2),
                    previousBlockHeaderHash: Data(),
                    merkleRoot: Data(),
                    timestamp: 1534820198,
                    bits: 402796414,
                    nonce: 1748283264
        ), height: 999)
        beforeEach {
            stub(mockBlockValidator) { mock in
                when(mock.validate(block: any(), previousBlock: any())).thenDoNothing()
                when(mock.isBlockValidatable(block: any(), previousBlock: any())).thenReturn(true)
            }
        }

        afterEach {
            reset(mockBlockValidator)
        }

        describe("#isBlockValidatable") {
            it("returns true when fork height is not equal") {
                let validatable = validator.isBlockValidatable(block: block, previousBlock: prevBlock)
                expect(validatable).to(beTrue())
            }
            it("returns false when fork height is equal") {
                let validatable = validator.isBlockValidatable(block: prevBlock, previousBlock: prevBlock)
                expect(validatable).to(beFalse())
            }
        }
        describe("#validate") {
            context("when block has fork height") {

                it("checks block hash and throw error when it's not equal expected") {
                    let wrongHashBlock = Block(
                            withHeader: BlockHeader(
                                    version: 536870912,
                                    headerHash: "01020304".reversedData!,
                                    previousBlockHeaderHash: Data(),
                                    merkleRoot: Data(),
                                    timestamp: 1534820198,
                                    bits: 402796414,
                                    nonce: 1748283264
                            ),
                            height: 1000)
                    do {
                        try validator.validate(block: wrongHashBlock, previousBlock: prevBlock)
                        XCTFail("Must throw BitcoinCoreErrors.BlockValidation.wrongHeaderHash error!")
                    } catch let error as BitcoinCoreErrors.BlockValidation {
                        expect(error).to(equal(BitcoinCoreErrors.BlockValidation.wrongHeaderHash))
                    } catch {
                        XCTFail("Must throw BitcoinCoreErrors.BlockValidation.wrongHeaderHash error!")
                    }
                }

                it("checks block hash and call concrete validate") {
                    do {
                        try validator.validate(block: block, previousBlock: prevBlock)
                        verify(mockBlockValidator).validate(block: equal(to: block), previousBlock: equal(to: prevBlock))
                    } catch {
                        XCTFail("Must no throwing error")
                    }
                }
            }
        }
    }
}
