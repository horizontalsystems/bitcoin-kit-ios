import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class OutputSetterTests: QuickSpec {

    override func spec() {
        describe("check set outputs") {
            let mockFactory = MockIFactory()
            let mockOutputSorterFactory = MockITransactionDataSorterFactory()
            let mockOutputSorter = MockITransactionDataSorter()

            let recipient = LegacyAddress(type: .pubKeyHash, keyHash: Data(repeating: 0, count: 20), base58: "")
            let change = LegacyAddress(type: .pubKeyHash, keyHash: Data(repeating: 0, count: 20), base58: "")

            var outputs = [Output]()
            outputs.append(Output(withValue: 100, index: 0, lockingScript: recipient.lockingScript, type: recipient.scriptType, address: recipient.stringValue, keyHash: recipient.keyHash))
            outputs.append(Output(withValue: 10, index: 0, lockingScript: change.lockingScript, type: change.scriptType, address: change.stringValue, keyHash: change.keyHash))

            beforeEach {
                stub(mockOutputSorterFactory) { mock in
                    when(mock.sorter(for: any())).thenReturn(mockOutputSorter)
                }
                stub(mockFactory) { mock in
                    when(mock.output(withIndex: 0, address: addressMatcher(recipient), value: 100, publicKey: isNil())).thenReturn(outputs[0])
                    when(mock.output(withIndex: 0, address: addressMatcher(change), value: 10, publicKey: isNil())).thenReturn(outputs[1])
                }
                stub(mockOutputSorter) { mock in
                    when(mock.sort(outputs: any())).thenReturn(outputs)
                }
            }
            it("calls outputSorter and set outputs to mutable tx") {
                let outputSetter = OutputSetter(outputSorterFactory: mockOutputSorterFactory, factory: mockFactory)
                let transaction = MutableTransaction()

                transaction.recipientAddress = recipient
                transaction.recipientValue = 100

                transaction.changeAddress = change
                transaction.changeValue = 10

                outputSetter.setOutputs(to: transaction, sortType: .none)
                verify(mockOutputSorterFactory).sorter(for: equal(to: TransactionDataSortType.none))
                verify(mockOutputSorter).sort(outputs: equal(to: outputs))

                expect(0).to(equal(outputs.first!.index))
                expect(1).to(equal(outputs.last!.index))
            }

        }

    }

}
