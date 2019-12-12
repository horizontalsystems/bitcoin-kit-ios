import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import DashKit
@testable import BitcoinCore

class MasternodeListMerkleRootCalculatorTests: QuickSpec {

    override func spec() {
        let mockSerializer = MockIMasternodeSerializer()
        let mockCreator = MockIMerkleRootCreator()
        let mockHasher = MockIDashHasher()
        var calculator: MasternodeListMerkleRootCalculator!
        beforeEach {
            calculator = MasternodeListMerkleRootCalculator(masternodeSerializer: mockSerializer, masternodeHasher: mockHasher, masternodeMerkleRootCreator: mockCreator)
        }

        afterEach {
            reset(mockSerializer, mockCreator, mockHasher)
            calculator = nil
        }

        describe("#calculateMerkleRoot(sortedMasternodes:)") {
            let masternodeData1 = Data(repeating: 1, count: 2)
            let masternodeData2 = Data(repeating: 2, count: 2)
            let masternodeHash1 = Data(repeating: 1, count: 32)
            let masternodeHash2 = Data(repeating: 2, count: 32)
            let masternodes = [DashTestData.masternode(proRegTxHash: masternodeData1), DashTestData.masternode(proRegTxHash: masternodeData2)]

            it("calculates for empty") {
                stub(mockCreator) { mock in
                    when(mock.create(hashes: equal(to: []))).thenReturn(nil)
                }

                let data = calculator.calculateMerkleRoot(sortedMasternodes: [])
                expect(data).to(beNil())

                verifyNoMoreInteractions(mockSerializer)
            }

            it("calculates for masternodes") {
                let hash = Data(repeating: 4, count: 4)
                stub(mockSerializer) { mock in
                    when(mock.serialize(masternode: equal(to: masternodes[0]))).thenReturn(masternodeData1)
                    when(mock.serialize(masternode: equal(to: masternodes[1]))).thenReturn(masternodeData2)
                }
                stub(mockHasher) { mock in
                    when(mock.hash(data: equal(to: masternodeData1))).thenReturn(masternodeHash1)
                    when(mock.hash(data: equal(to: masternodeData2))).thenReturn(masternodeHash2)
                }
                stub(mockCreator) { mock in
                    when(mock.create(hashes: equal(to: [masternodeHash1, masternodeHash2]))).thenReturn(hash)
                }
                let data = calculator.calculateMerkleRoot(sortedMasternodes: masternodes)

                verify(mockSerializer).serialize(masternode: equal(to: masternodes[0]))
                verify(mockSerializer).serialize(masternode: equal(to: masternodes[1]))

                expect(data).to(equal(hash))
            }
        }
    }

}
