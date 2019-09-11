import XCTest
import Cuckoo
import Nimble
import Quick
@testable import BitcoinCore

class TransactionFeeCalculatorTests: QuickSpec {
    override func spec() {
        let mockUnspentOutputSelector = MockIUnspentOutputSelector()
        let mockTransactionSizeCalculator = MockITransactionSizeCalculator()
        let mockTransactionBuilder = MockITransactionBuilder()

        let toAddress = LegacyAddress(type: .pubKeyHash, keyHash: randomBytes(length: 32), base58: "toAddress")
        let changeAddress = LegacyAddress(type: .pubKeyHash, keyHash: randomBytes(length: 32), base58: "changeAddress")
        let value = 100_000_000
        let feeRate = 10
        let senderPay = true
        let fee = 1000
        let transaction = TestData.p2pkhTransaction
        let unspentOutputs = [
            UnspentOutput(
                    output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2pkh),
                    publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                    transaction: Transaction(),
                    blockHeight: 1000
            )
        ]

        var selectedOutputsInfo: SelectedUnspentOutputInfo!
        var resultFee: Int!

        var calculator: TransactionFeeCalculator!

        beforeEach() {
            selectedOutputsInfo = SelectedUnspentOutputInfo(unspentOutputs: unspentOutputs, totalValue: 100_000_000, fee: fee, addChangeOutput: true)

            stub(mockUnspentOutputSelector) { mock in
                when(mock.select(value: any(), feeRate: any(), outputScriptType: any(), changeType: any(), senderPay: any())).thenReturn(selectedOutputsInfo)
            }
            stub(mockTransactionBuilder) { mock in
                when(mock.buildTransaction(value: any(), unspentOutputs: any(), fee: any(), senderPay: any(), toAddress: any(), changeAddress: any())).thenReturn(transaction)
            }

            calculator = TransactionFeeCalculator(unspentOutputSelector: mockUnspentOutputSelector, transactionSizeCalculator: mockTransactionSizeCalculator, transactionBuilder: mockTransactionBuilder)
        }

        afterEach() {
            reset(mockUnspentOutputSelector, mockTransactionBuilder, mockTransactionSizeCalculator)
            calculator = nil
            resultFee = nil
            selectedOutputsInfo = nil
        }

        describe("fee(for:feeRate:senderPay:toAddress:changeAddress:)") {
            context("when toAddress exists") {
                context("when addChangeOutput is true") {
                    beforeEach() {
                        resultFee = try! calculator.fee(for: value, feeRate: feeRate, senderPay: senderPay, toAddress: toAddress, changeAddress: changeAddress)
                    }

                    it("selects unspent outputs with given parameters") {
                        verify(mockUnspentOutputSelector).select(value: value, feeRate: feeRate, outputScriptType: equal(to: toAddress.scriptType), changeType: equal(to: changeAddress.scriptType), senderPay: senderPay)
                    }

                    it("builds actual transaction and returns fee") {
                        verify(mockTransactionBuilder).buildTransaction(value: value, unspentOutputs: equal(to: unspentOutputs), fee: fee, senderPay: senderPay, toAddress: addressMatcher(toAddress), changeAddress: addressMatcher(changeAddress))
                        expect(resultFee).to(equal(TransactionSerializer.serialize(transaction: transaction, withoutWitness: true).count * feeRate))
                    }
                }

                context("when addChangeOutput is false") {
                    beforeEach() {
                        selectedOutputsInfo = SelectedUnspentOutputInfo(unspentOutputs: unspentOutputs, totalValue: 100_000_000, fee: fee, addChangeOutput: false)
                        stub(mockUnspentOutputSelector) { mock in
                            when(mock.select(value: any(), feeRate: any(), outputScriptType: any(), changeType: any(), senderPay: any())).thenReturn(selectedOutputsInfo)
                        }

                        resultFee = try! calculator.fee(for: value, feeRate: feeRate, senderPay: senderPay, toAddress: toAddress, changeAddress: changeAddress)
                    }

                    it("builds actual transaction without changeAddress") {
                        verify(mockTransactionBuilder).buildTransaction(value: value, unspentOutputs: equal(to: unspentOutputs), fee: fee, senderPay: senderPay, toAddress: addressMatcher(toAddress), changeAddress: addressMatcher(nil))
                    }
                }
            }

            context("when toAddress is nil") {
                it("selects unspent outputs with given parameters and returns fee") {
                    resultFee = try! calculator.fee(for: value, feeRate: feeRate, senderPay: senderPay, toAddress: nil, changeAddress: changeAddress)
                    verify(mockUnspentOutputSelector).select(value: value, feeRate: feeRate, outputScriptType: equal(to: toAddress.scriptType), changeType: equal(to: changeAddress.scriptType), senderPay: senderPay)
                    verify(mockTransactionBuilder, never()).buildTransaction(value: any(), unspentOutputs: any(), fee: any(), senderPay: any(), toAddress: any(), changeAddress: any())
                    expect(resultFee).to(equal(fee))
                }
            }
        }

        describe("feeWithUnspentOutputs") {
            it("selects unspent outputs with given parameters and returns it") {
                let feeWithUnspentOutputs = try! calculator.feeWithUnspentOutputs(value: value, feeRate: feeRate, toScriptType: toAddress.scriptType, changeScriptType: changeAddress.scriptType, senderPay: senderPay)
                verify(mockUnspentOutputSelector).select(value: value, feeRate: feeRate, outputScriptType: equal(to: toAddress.scriptType), changeType: equal(to: changeAddress.scriptType), senderPay: senderPay)
                expect(feeWithUnspentOutputs.fee).to(equal(selectedOutputsInfo.fee))
            }
        }

        describe("fee(inputScriptType:outputScriptType:feeRate:signatureScriptFunction:)") {
            let signatureData = [randomBytes(length: TransactionSizeCalculator.signatureLength), randomBytes(length: TransactionSizeCalculator.pubKeyLength)]
            let signatureScript = randomBytes(length: 100)
            var signatureScriptFunctionCalled = false
            let signatureScriptFunction: ((Data, Data) -> Data) = { (signature: Data, publicKey: Data) in
                XCTAssertEqual(signature.count, signatureData[0].count)
                XCTAssertEqual(publicKey.count, signatureData[1].count)
                signatureScriptFunctionCalled = true
                return signatureScript
            }
            let size = 500

            it("calculates fee from transaction size returns it") {
                stub(mockTransactionSizeCalculator) { mock in
                    when(mock).transactionSize(inputs: any(), outputScriptTypes: any()).thenReturn(size)
                }

                resultFee = calculator.fee(inputScriptType: .p2pkh, outputScriptType: .p2pkh, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
                let expectedFee = (size + signatureScript.count) * feeRate

                verify(mockTransactionSizeCalculator).transactionSize(inputs: equal(to: [.p2pkh]), outputScriptTypes: equal(to: [.p2pkh]))
                expect(resultFee).to(equal(expectedFee))
                expect(signatureScriptFunctionCalled).to(beTrue())
            }
        }
    }
}
