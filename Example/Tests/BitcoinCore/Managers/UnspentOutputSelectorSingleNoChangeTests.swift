import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class UnspentOutputSelectorSingleNoChangeTests: QuickSpec {

    override func spec() {
        let feeRate = 1
        let fee = 100
        let dust = 12
        let value = 4000

        let mockTransactionSizeCalculator = MockITransactionSizeCalculator()
        let mockUnspentOutputProvider = MockIUnspentOutputProvider()
        let mockDustCalculator = MockIDustCalculator()
        var selector: UnspentOutputSelectorSingleNoChange!

        let outputs = [TestData.unspentOutput(output: Output(withValue: dust + fee, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 2000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 4000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 8000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                       TestData.unspentOutput(output: Output(withValue: 16000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()))
        ]

        beforeEach {
            stub(mockTransactionSizeCalculator) { mock in
                when(mock.inputSize(type: any())).thenReturn(10)
                when(mock.outputSize(type: any())).thenReturn(2)
                when(mock.transactionSize(previousOutputs: any(), outputScriptTypes: any(), pluginDataOutputSize: any())).thenReturn(fee)
            }
            stub(mockUnspentOutputProvider) { mock in
                when(mock.spendableUtxo.get).thenReturn(outputs)
            }
            stub(mockDustCalculator) { mock in
                when(mock.dust(type: any())).thenReturn(dust)
            }
            selector = UnspentOutputSelectorSingleNoChange(calculator: mockTransactionSizeCalculator, provider: mockUnspentOutputProvider, dustCalculator: mockDustCalculator)
        }

        afterEach {
            reset(mockTransactionSizeCalculator, mockUnspentOutputProvider)
            selector = nil
        }

        context("when senderPay = true") {
            it("selects it on exact match") {
                var selectedOutputs = try! selector.select(value: value - fee, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                expect(selectedOutputs.unspentOutputs).to(equal([outputs[2]]))
                expect(selectedOutputs.recipientValue).to(equal(value - fee))
                expect(selectedOutputs.changeValue).to(beNil())

                selectedOutputs = try! selector.select(value: dust, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                expect(selectedOutputs.unspentOutputs).to(equal([outputs[0]]))
                expect(selectedOutputs.recipientValue).to(equal(dust))
                expect(selectedOutputs.changeValue).to(beNil())
            }

            it("selects it on match with allowable remainder") {
                let selectedOutputs = try! selector.select(value: value - fee - dust + 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                expect(selectedOutputs.unspentOutputs).to(equal([outputs[2]]))
                expect(selectedOutputs.recipientValue).to(equal(value - fee - dust + 1))
                expect(selectedOutputs.changeValue).to(beNil())
            }

            it("doesn't select it on match with remainder more than dust") {
                do {
                    _ = try selector.select(value: value - fee - dust, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: true, pluginDataOutputSize: 0)
                    fail("Exception expected")
                } catch let error as BitcoinCoreErrors.SendValueErrors {
                    expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.singleNoChangeOutputNotFound))
                } catch {
                    fail("Unexpected error")
                }
            }

            it("throws exception on value less than dust") {
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

        context("when senderPay = false") {
            it("selects it on exact match") {
                let selectedOutputs = try! selector.select(value: value, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                expect(selectedOutputs.unspentOutputs).to(equal([outputs[2]]))
                expect(selectedOutputs.recipientValue).to(equal(value - fee))
                expect(selectedOutputs.changeValue).to(beNil())
            }

            it("selects it on match with allowable remainder") {
                let selectedOutputs = try! selector.select(value: value - dust + 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                expect(selectedOutputs.unspentOutputs).to(equal([outputs[2]]))
                expect(selectedOutputs.recipientValue).to(equal(value - fee - dust + 1))
                expect(selectedOutputs.changeValue).to(beNil())
            }

            it("doesn't select it on match with remainder more than dust") {
                do {
                    _ = try selector.select(value: value - dust, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                    fail("Exception expected")
                } catch let error as BitcoinCoreErrors.SendValueErrors {
                    expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.singleNoChangeOutputNotFound))
                } catch {
                    fail("Unexpected error")
                }
            }

            it("doesn't select it on recipientValue less than dust") {
                do {
                    _ = try selector.select(value: dust + fee - 1, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                    fail("Exception expected")
                } catch let error as BitcoinCoreErrors.SendValueErrors {
                    expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.singleNoChangeOutputNotFound))
                } catch {
                    fail("Unexpected error")
                }
            }

            it("doesn't select it if there's an output failed to spend before") {
                defer {
                    outputs.first?.output.failedToSpend = false
                }

                do {
                    outputs.first?.output.failedToSpend = true
                    _ = try selector.select(value: value, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: false, pluginDataOutputSize: 0)
                    fail("Exception expected")
                } catch let error as BitcoinCoreErrors.SendValueErrors {
                    expect(error).to(equal(BitcoinCoreErrors.SendValueErrors.singleNoChangeOutputNotFound))
                } catch {
                    fail("Unexpected error")
                }
            }
        }
    }

}

