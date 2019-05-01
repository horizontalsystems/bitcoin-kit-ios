import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore
@testable import DashKit

class DashUnspentOutputSelectorTests: QuickSpec {
    static let feeRate = 1 // duffs/Byte for standard tx

    override func spec() {
        let mockTransactionSizeCalculator = MockIDashTransactionSizeCalculator()
        var selector: DashUnspentOutputSelector!

        let outputs = [DashTestData.unspentOutput(output: Output(withValue: 1000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       DashTestData.unspentOutput(output: Output(withValue: 2000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       DashTestData.unspentOutput(output: Output(withValue: 4000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       DashTestData.unspentOutput(output: Output(withValue: 8000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       DashTestData.unspentOutput(output: Output(withValue: 16000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()))
        ]

        beforeEach {
            stub(mockTransactionSizeCalculator) { mock in
                when(mock.inputSize(type: any())).thenReturn(8)
                when(mock.outputSize(type: any())).thenReturn(2)
                when(mock.transactionSize(inputs: any(), outputScriptTypes: any())).thenReturn(100)
            }
            selector = DashUnspentOutputSelector(calculator: mockTransactionSizeCalculator)
        }

        afterEach {
            reset(mockTransactionSizeCalculator)
            selector = nil
        }

        describe("#select") {
            it("selects exactly output") {
                let testBlock: ((Int, Int, Int, Bool, UnspentOutput) -> ()) = { value, feeRate, fee, senderPay, unspentOutput in
                    do {
                        let selectedOutputs = try selector.select(value: value, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: senderPay, unspentOutputs: outputs)
                        expect(selectedOutputs.unspentOutputs).to(equal([unspentOutput]))
                        expect(selectedOutputs.totalValue).to(equal(unspentOutput.output.value))
                        expect(selectedOutputs.fee).to(equal(fee))
                        expect(selectedOutputs.addChangeOutput).to(equal(false))
                    } catch {
                        XCTFail("Unexpected error! \(error)")
                    }
                }
                testBlock(4000, DashUnspentOutputSelectorTests.feeRate, 100, false, outputs[2])
                testBlock(4000 - 10, DashUnspentOutputSelectorTests.feeRate, 100, false, outputs[2])

                testBlock(3900, DashUnspentOutputSelectorTests.feeRate, 100, true, outputs[2])
                testBlock(4000 - 100 - 10, DashUnspentOutputSelectorTests.feeRate, 100 + 10, true, outputs[2])
            }
            it("selects summary outputs") {
                do {
                    let selectedOutputs = try selector.select(value: 6499, feeRate: 1, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, unspentOutputs: outputs)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[1], outputs[2]]))
                    expect(selectedOutputs.totalValue).to(equal(7000))
                    expect(selectedOutputs.fee).to(equal(100))
                    expect(selectedOutputs.addChangeOutput).to(equal(true))
                } catch {
                    XCTFail("Unexpected error! \(error)")
                }
            }
            it("selects summary outputs and remove non needed") {
                do {
                    let selectedOutputs = try selector.select(value: 7500, feeRate: 1, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, unspentOutputs: outputs)

                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[3]]))
                    expect(selectedOutputs.totalValue).to(equal(9000))
                    expect(selectedOutputs.fee).to(equal(100))
                    expect(selectedOutputs.addChangeOutput).to(equal(true))
                } catch {
                    XCTFail("Unexpected error! \(error)")
                }
            }
        }
    }

}

