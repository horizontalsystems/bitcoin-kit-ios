import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import DashKit

class MasternodeCbTxHashCalculatorTests: QuickSpec {

    override func spec() {
        let mockSerializer = MockICoinbaseTransactionSerializer()
        let mockHasher = MockIDashHasher()

        var calculator: MasternodeCbTxHasher!

        beforeEach {
            calculator = MasternodeCbTxHasher(coinbaseTransactionSerializer: mockSerializer, hasher: mockHasher)
        }

        afterEach {
            reset(mockSerializer, mockHasher)
            calculator = nil
        }

        let merkleRootMNList = Data(repeating: 1, count: 32)
        let cbTx = DashTestData.coinbaseTransaction(merkleRootMNList: merkleRootMNList)

        describe("#calculate(cbTx:)") {
            it("calculate value") {
                let serializedData = Data(repeating: 2, count: 64)
                let hash = Data(repeating: 3, count: 32)

                stub(mockSerializer) { mock in
                    when(mock.serialize(coinbaseTransaction: equal(to: cbTx))).thenReturn(serializedData)
                }
                stub(mockHasher) { mock in
                    when(mock.hash(data: equal(to:serializedData))).thenReturn(hash)
                }
                let data = calculator.hash(coinbaseTransaction: cbTx)
                expect(data).to(equal(hash))
            }
        }
    }
}

