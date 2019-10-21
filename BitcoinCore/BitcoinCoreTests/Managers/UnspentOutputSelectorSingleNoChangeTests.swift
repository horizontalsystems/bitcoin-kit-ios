import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class UnspentOutputSelectorSingleNoChangeTests: QuickSpec {
    static let feeRate = 1

    override func spec() {
        let mockTransactionSizeCalculator = MockITransactionSizeCalculator()
        let mockUnspentOutputProvider = MockIUnspentOutputProvider()
        var selector: UnspentOutputSelectorSingleNoChange!

        let outputs = [TestData.unspentOutput(output: Output(withValue: 1000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 2000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 4000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 8000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 16000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()))
        ]

        beforeEach {
            stub(mockTransactionSizeCalculator) { mock in
                when(mock.inputSize(type: any())).thenReturn(10)
                when(mock.outputSize(type: any())).thenReturn(2)
                when(mock.transactionSize(inputs: any(), outputScriptTypes: any(), pluginDataOutputSize: any())).thenReturn(100)
            }
            stub(mockUnspentOutputProvider) { mock in
                when(mock.spendableUtxo.get).thenReturn(outputs)
            }
            selector = UnspentOutputSelectorSingleNoChange(calculator: mockTransactionSizeCalculator, provider: mockUnspentOutputProvider)
        }

        afterEach {
            reset(mockTransactionSizeCalculator, mockUnspentOutputProvider)
            selector = nil
        }

        context("select exactly value receiver pay") {
            it("selects exactly output") {
                let testBlock: ((Int, Int, Int, Bool, UnspentOutput) -> ()) = { value, feeRate, fee, senderPay, unspentOutput in
                    do {
                        let selectedOutputs = try selector.select(value: value, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: senderPay, pluginDataOutputSize: 0)
                        expect(selectedOutputs.unspentOutputs).to(equal([unspentOutput]))
                        expect(selectedOutputs.totalValue).to(equal(unspentOutput.output.value))
                        expect(selectedOutputs.fee).to(equal(fee))
                        expect(selectedOutputs.addChangeOutput).to(equal(false))
                    } catch {
                        XCTFail("Unexpected error! \(error)")
                    }
                }
                testBlock(4000, UnspentOutputSelectorSingleNoChangeTests.feeRate, 100, false, outputs[2])
                testBlock(4000 - 10, UnspentOutputSelectorSingleNoChangeTests.feeRate, 100, false, outputs[2])

                testBlock(3900, UnspentOutputSelectorSingleNoChangeTests.feeRate, 100, true, outputs[2])
                testBlock(4000 - 100 - 10, UnspentOutputSelectorSingleNoChangeTests.feeRate, 100 + 10, true, outputs[2])
            }
        }
    }

}

