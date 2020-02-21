import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class MutableTransactionTests: QuickSpec {

    override func spec() {
        describe("check output indexes") {

            it("indexes up") {
                let transaction = MutableTransaction()
                transaction.recipientAddress = LegacyAddress(type: .pubKeyHash, keyHash: Data(repeating: 0, count: 20), base58: "")
                transaction.recipientValue = 100
                transaction.changeAddress = LegacyAddress(type: .pubKeyHash, keyHash: Data(repeating: 0, count: 20), base58: "")
                transaction.changeValue = 10

                let outputs = transaction.outputs
                expect(0).to(equal(outputs.first!.index))
                expect(1).to(equal(outputs.last!.index))
            }

            it("indexes down") {
                let transaction = MutableTransaction()
                transaction.recipientAddress = LegacyAddress(type: .pubKeyHash, keyHash: Data(repeating: 0, count: 20), base58: "")
                transaction.recipientValue = 10
                transaction.changeAddress = LegacyAddress(type: .pubKeyHash, keyHash: Data(repeating: 0, count: 20), base58: "")
                transaction.changeValue = 100

                let outputs = transaction.outputs
                expect(0).to(equal(outputs.first!.index))
                expect(1).to(equal(outputs.last!.index))
            }

        }

    }

}
