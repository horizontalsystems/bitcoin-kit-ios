import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

//   value:              Given value
//   totalValue:         Total value of selected UTXOs
//   recipientValue:     Actual value receiver gets. A value in "TO" output
//   sentValue:          Value that sender actually loses. (recipientValue + fee)
//   changeValue:        Value in "CHANGE" output
//
//
//
//   INPUTS                         OUTPUTS
//
//   totalValue   - - fee - ->      recipientValue
//                        \
//                          ->      changeValue
//
//
//   * when senderPay = true:   recipientValue = value;        sentValue = value + fee
//     when senderPay = false:  recipientValue = value - fee;  sentValue = value


class UnspentOutputSelectorTests: QuickSpec {

    override func spec() {
        let feeRate = 1
        let fee = 100
        let feeWithChangeOutput = 110
        let dust = 12
        let totalValue = 1000 + 2000

        let mockTransactionSizeCalculator = MockITransactionSizeCalculator()
        let mockUnspentOutputProvider = MockIUnspentOutputProvider()
        let mockDustCalculator = MockIDustCalculator()
        var selector: UnspentOutputSelector!

        let outputs = [TestData.unspentOutput(output: Output(withValue: 1000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 2000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 3000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 8000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 16000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()))
        ]

        beforeEach {
            stub(mockTransactionSizeCalculator) { mock in
                when(mock.inputSize(type: any())).thenReturn(10)
                when(mock.outputSize(type: any())).thenReturn(2)
                when(mock.transactionSize(previousOutputs: any(), outputScriptTypes: equal(to: [.p2pkh]), pluginDataOutputSize: any())).thenReturn(fee)
                when(mock.transactionSize(previousOutputs: any(), outputScriptTypes: equal(to: [.p2pkh, .p2pkh]), pluginDataOutputSize: any())).thenReturn(feeWithChangeOutput)
            }
            stub(mockUnspentOutputProvider) { mock in
                when(mock.spendableUtxo.get).thenReturn(outputs)
            }
            stub(mockDustCalculator) { mock in
                when(mock.dust(type: any())).thenReturn(dust)
            }
            selector = UnspentOutputSelector(calculator: mockTransactionSizeCalculator, provider: mockUnspentOutputProvider, dustCalculator: mockDustCalculator)
        }

        afterEach {
            reset(mockTransactionSizeCalculator, mockUnspentOutputProvider)
            selector = nil
        }

        context("when senderPay = true") {
            context("when totalValue exactly matches recipientValue + fee") {
                it("selects without changeValue") {
                    // CONDITION: totalValue == recipientValue + fee
                    // recipientValue = givenValue
                    // givenValue = totalValue - fee
                    // CONDITION CHECK: totalValue == (totalValue - fee) + fee
                    let selectedOutputs = try! selector.select(value: totalValue - fee, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[1]]))
                    expect(selectedOutputs.recipientValue).to(equal(totalValue - fee))
                    expect(selectedOutputs.changeValue).to(beNil())
                }
            }

            context("when totalValue matches value with remainder less than dust") {
                it("selects without changeValue") {
                    // CONDITION: totalValue == recipientValue + fee + (dust - 1)
                    // recipientValue = givenValue
                    // givenValue = totalValue - fee - dust + 1
                    // CONDITION CHECK: totalValue == (totalValue - fee - dust + 1) + fee + (dust - 1)
                    let selectedOutputs = try! selector.select(value: totalValue - fee - dust + 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[1]]))
                    expect(selectedOutputs.recipientValue).to(equal(totalValue - fee - dust + 1))
                    expect(selectedOutputs.changeValue).to(beNil())
                }
            }

            context("when totalValue matches value with remainder more than or equal to dust") {
                it("selects with changeValue") {
                    // CONDITION: totalValue == recipientValue + fee + dust
                    // recipientValue = givenValue
                    // givenValue = totalValue - feeWithChangeOutput - dust
                    // CONDITION CHECK: totalValue == (totalValue - feeWithChangeOutput - dust) + fee + dust
                    let selectedOutputs = try! selector.select(value: totalValue - feeWithChangeOutput - dust, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[1]]))
                    expect(selectedOutputs.recipientValue).to(equal(totalValue - feeWithChangeOutput - dust))
                    expect(selectedOutputs.changeValue).to(equal(dust))
                }
            }

            context("when value is less than dust") {
                it("throws dust exception") {
                    do {
                        _ = try selector.select(value: dust - 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                        fail("Exception expected")
                    } catch let error as BitcoinCoreErrors.SendValueErrors {
                        expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.dust))
                    } catch {
                        fail("Unexpected error")
                    }
                }
            }

            context("when value is less than allAmount") {
                it("throws notEnough exception") {
                    do {
                        _ = try selector.select(value: outputs.reduce(0) { $0 + $1.output.value } - fee + 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                        fail("Exception expected")
                    } catch let error as BitcoinCoreErrors.SendValueErrors {
                        expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.notEnough))
                    } catch {
                        fail("Unexpected error")
                    }
                }
            }

            context("when there is an output failed to spend before") {
                beforeEach {
                    outputs[2].output.failedToSpend = true
                }
                afterEach {
                    outputs[2].output.failedToSpend = false
                }

                it("selects output failed to spend") {
                    let selectedOutputs = try! selector.select(value: totalValue - fee, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[2]]))
                    expect(selectedOutputs.recipientValue).to(equal(totalValue - fee))
                    expect(selectedOutputs.changeValue).to(beNil())
                }
            }
        }

        context("when senderPay = false") {
            context("when totalValue exactly matches recipientValue + fee") {
                it("selects without changeValue") {
                    // CONDITION: totalValue == recipientValue + fee
                    // recipientValue = givenValue - fee
                    // givenValue = totalValue
                    // CONDITION CHECK: totalValue == (totalValue - fee) + fee
                    let selectedOutputs = try! selector.select(value: totalValue, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[1]]))
                    expect(selectedOutputs.recipientValue).to(equal(totalValue - fee))
                    expect(selectedOutputs.changeValue).to(beNil())
                }
            }

            context("when totalValue matches value with remainder less than dust") {
                it("selects without changeValue") {
                    // CONDITION: totalValue == recipientValue + fee + (dust - 1)
                    // recipientValue = givenValue - fee
                    // givenValue = totalValue - dust + 1
                    // CONDITION CHECK: totalValue == ((totalValue - dust + 1) - fee) + fee + (dust - 1)
                    let selectedOutputs = try! selector.select(value: totalValue - dust + 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[1]]))
                    expect(selectedOutputs.recipientValue).to(equal(totalValue - dust + 1 - fee))
                    expect(selectedOutputs.changeValue).to(beNil())
                }
            }

            context("when totalValue matches value with remainder more than or equal to dust") {
                it("selects with changeValue") {
                    // CONDITION: totalValue == recipientValue + feeWithChangeOutput + dust
                    // recipientValue = givenValue - feeWithChangeOutput
                    // givenValue = totalValue - dust
                    // CONDITION CHECK: totalValue == ((totalValue - dust) - feeWithChangeOutput) + feeWithChangeOutput + dust
                    let selectedOutputs = try! selector.select(value: totalValue - dust, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                    expect(selectedOutputs.unspentOutputs).to(equal([outputs[0], outputs[1]]))
                    expect(selectedOutputs.recipientValue).to(equal(totalValue - dust - feeWithChangeOutput))
                    expect(selectedOutputs.changeValue).to(equal(dust))
                }
            }

            context("when value is less than dust") {
                it("throws dust exception") {
                    do {
                        _ = try selector.select(value: dust + fee - 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                        fail("Exception expected")
                    } catch let error as BitcoinCoreErrors.SendValueErrors {
                        expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.dust))
                    } catch {
                        fail("Unexpected error")
                    }
                }
            }

            context("when value is less than allAmount") {
                it("throws notEnough exception") {
                    do {
                        _ = try selector.select(value: outputs.reduce(0) { $0 + $1.output.value } + 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                        fail("Exception expected")
                    } catch let error as BitcoinCoreErrors.SendValueErrors {
                        expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.notEnough))
                    } catch {
                        fail("Unexpected error")
                    }
                }
            }
        }
    }

}
