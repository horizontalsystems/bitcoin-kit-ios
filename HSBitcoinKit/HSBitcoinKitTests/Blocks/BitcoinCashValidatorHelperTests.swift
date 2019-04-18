import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import HSBitcoinKit

class BitcoinCashValidatorHelperTests: QuickSpec {

    override func spec() {
        var helper: BitcoinCashBlockValidatorHelper!
        let mockStorage = MockIBitcoinCashStorage()

        beforeEach {
            helper = BitcoinCashBlockValidatorHelper(storage: mockStorage)
        }

        afterEach {
            reset(mockStorage)
            helper = nil
        }

        describe("#getSuitableBlockIndex") {
            it("getSuitableBlock") {
                let block1 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "11")!, previousBlockHeaderHash: Data(hex: "00")!, merkleRoot: Data(), timestamp: 10, bits: 0, nonce: 0), height: 1)
                let block2 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "22")!, previousBlockHeaderHash: Data(hex: "11")!, merkleRoot: Data(), timestamp: 20, bits: 0, nonce: 0), height: 2)
                let block3 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "33")!, previousBlockHeaderHash: Data(hex: "22")!, merkleRoot: Data(), timestamp: 30, bits: 0, nonce: 0), height: 3)

                stub(mockStorage) { mock in
                    when(mock.block(byHashHex: (block3.previousBlockHashReversedHex))).thenReturn(block2)
                    when(mock.block(byHashHex: (block2.previousBlockHashReversedHex))).thenReturn(block1)
                }

                let blockIndex = helper.suitableBlockIndex(for: [block1, block2, block3])
                expect(blockIndex).to(equal(1))
            }
            it("getSuitableBlock_sameTime") {
                let block1 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "11")!, previousBlockHeaderHash: Data(hex: "00")!, merkleRoot: Data(), timestamp: 10, bits: 0, nonce: 0), height: 1)
                let block2 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "22")!, previousBlockHeaderHash: Data(hex: "11")!, merkleRoot: Data(), timestamp: 20, bits: 0, nonce: 0), height: 2)
                let block3 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "33")!, previousBlockHeaderHash: Data(hex: "22")!, merkleRoot: Data(), timestamp: 20, bits: 0, nonce: 0), height: 3)

                stub(mockStorage) { mock in
                    when(mock.block(byHashHex: (block3.previousBlockHashReversedHex))).thenReturn(block2)
                    when(mock.block(byHashHex: (block2.previousBlockHashReversedHex))).thenReturn(block1)
                }

                let blockIndex = helper.suitableBlockIndex(for: [block1, block2, block3])
                expect(blockIndex).to(equal(1))
            }
            it("getSuitableBlock_wrongOrdering") {
                let block1 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "11")!, previousBlockHeaderHash: Data(hex: "00")!, merkleRoot: Data(), timestamp: 20, bits: 0, nonce: 0), height: 1)
                let block2 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "22")!, previousBlockHeaderHash: Data(hex: "11")!, merkleRoot: Data(), timestamp: 10, bits: 0, nonce: 0), height: 2)
                let block3 = Block(withHeader: BlockHeader(version: 0, headerHash: Data(hex: "33")!, previousBlockHeaderHash: Data(hex: "22")!, merkleRoot: Data(), timestamp: 20, bits: 0, nonce: 0), height: 3)

                stub(mockStorage) { mock in
                    when(mock.block(byHashHex: (block3.previousBlockHashReversedHex))).thenReturn(block2)
                    when(mock.block(byHashHex: (block2.previousBlockHashReversedHex))).thenReturn(block1)
                }

                let blockIndex = helper.suitableBlockIndex(for: [block1, block2, block3])
                expect(blockIndex).to(equal(0))
            }
        }
        describe("#medianTimePast") {
            it("checks valid median time past") {
                let block = TestData.firstBlock
                block.height = 1000

                var timestamps = [Int]()
                for i in 0..<11 {
                    timestamps.append(100 * (i + 1))
                }
                stub(mockStorage) { mock in
                    when(mock.timestamps(from: 990, to: 1000, ascending: true)).thenReturn(timestamps)
                }

                let medianTime = helper.medianTimePast(block: block)
                expect(medianTime).to(equal(600))
            }
        }
    }

}
