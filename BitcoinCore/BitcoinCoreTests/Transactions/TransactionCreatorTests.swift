import XCTest
import Cuckoo
import Nimble
import Quick
@testable import BitcoinCore

class TransactionCreatorTests: QuickSpec {
    override func spec() {
        let mockTransactionBuilder = MockITransactionBuilder()
        let mockTransactionProcessor = MockITransactionProcessor()
        let mockTransactionSender = MockITransactionSender()
        let mockBloomFilterManager = MockIBloomFilterManager()

        var transactionCreator: TransactionCreator!
        let transaction = TestData.p2pkhTransaction

        afterEach {
            reset(mockTransactionBuilder, mockTransactionProcessor, mockTransactionSender, mockBloomFilterManager)
            transactionCreator = nil
        }

        describe("#create(to:value:feeRate:senderPay:)") {
            beforeEach {
                stub(mockTransactionBuilder) { mock in
                    when(mock.buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any(), changeScriptType: any())).thenReturn(transaction)
                }
                stub(mockTransactionProcessor) { mock in
                    when(mock.processCreated(transaction: any())).thenDoNothing()
                }
                stub(mockTransactionSender) { mock in
                    when(mock.send(pendingTransaction: any())).thenDoNothing()
                }
                stub(mockBloomFilterManager) { mock in
                    when(mock.regenerateBloomFilter()).thenDoNothing()
                }

                transactionCreator = TransactionCreator(transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, transactionSender: mockTransactionSender, bloomFilterManager: mockBloomFilterManager)
            }

            context("when BloomFilterManager.BloomFilterExpired error") {
                beforeEach {
                    stub(mockTransactionProcessor) { mock in
                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try? transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false, changeScriptType: .p2pkh)
                }

                it("does create transaction") {
                    verify(mockTransactionBuilder).buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any(), changeScriptType: any())
                    verify(mockTransactionProcessor).processCreated(transaction: any())
                }

                it("does send transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }

                it("regenerates bloomfilter") {
                    verify(mockBloomFilterManager).regenerateBloomFilter()
                }
            }

            context("when other error") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenThrow(BitcoinCoreErrors.TransactionSendError.noConnectedPeers)
                    }

                    _ = try? transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false, changeScriptType: .p2pkh)
                }

                it("doesn't create transaction") {
                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
                }

                it("doesn't regenerate bloomfilter") {
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }

            context("when success") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }
                }

                context("when changeScriptType is .p2pkh") {
                    beforeEach {
                        _ = try! transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false, changeScriptType: .p2pkh)
                    }

                    it("creates transaction") {
                        verify(mockTransactionBuilder).buildTransaction(value: 0, feeRate: 0, senderPay: false, toAddress: "", changeScriptType: equal(to: ScriptType.p2pkh))
                        verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                    }

                    it("sends transaction") {
                        verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                    }
                }

                context("when changeScriptType is .p2wpkh") {
                    it("create transaction with p2wpkh change output") {
                        _ = try! transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false, changeScriptType: .p2wpkh)
                        verify(mockTransactionBuilder).buildTransaction(value: 0, feeRate: 0, senderPay: false, toAddress: "", changeScriptType: equal(to: ScriptType.p2wpkh))
                        verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                    }
                }
            }
        }

        describe("#create(from:to:feeRate:signatureScriptFunction:)") {
            let unspentOutput = UnspentOutput(output: TestData.p2shTransaction.outputs[0], publicKey: TestData.pubKey(), transaction: Transaction(), blockHeight: nil)
            let signatureScriptFunction: (Data, Data) -> Data = { return $0 + $1 }

            beforeEach {
                stub(mockTransactionBuilder) { mock in
                    when(mock.buildTransaction(from: any(), to: any(), feeRate: any(), signatureScriptFunction: any())).thenReturn(transaction)
                }
                stub(mockTransactionProcessor) { mock in
                    when(mock.processCreated(transaction: any())).thenDoNothing()
                }
                stub(mockTransactionSender) { mock in
                    when(mock.send(pendingTransaction: any())).thenDoNothing()
                }
                stub(mockBloomFilterManager) { mock in
                    when(mock.regenerateBloomFilter()).thenDoNothing()
                }

                transactionCreator = TransactionCreator(transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, transactionSender: mockTransactionSender, bloomFilterManager: mockBloomFilterManager)
            }

            context("when BloomFilterManager.BloomFilterExpired error") {
                beforeEach {
                    stub(mockTransactionProcessor) { mock in
                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try? transactionCreator.create(from: unspentOutput, to: "", feeRate: 0, signatureScriptFunction: signatureScriptFunction)
                }

                it("does create transaction") {
                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), to: "", feeRate: 0, signatureScriptFunction: any())
                    verify(mockTransactionProcessor).processCreated(transaction: any())
                }

                it("does send transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }

                it("regenerates bloomfilter") {
                    verify(mockBloomFilterManager).regenerateBloomFilter()
                }
            }

            context("when other error") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenThrow(BitcoinCoreErrors.TransactionSendError.noConnectedPeers)
                    }

                    _ = try? transactionCreator.create(from: unspentOutput, to: "", feeRate: 0, signatureScriptFunction: signatureScriptFunction)
                }

                it("doesn't create transaction") {
                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
                }

                it("doesn't regenerate bloomfilter") {
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }

            context("when success") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try! transactionCreator.create(from: unspentOutput, to: "", feeRate: 0, signatureScriptFunction: signatureScriptFunction)
                }

                it("creates transaction") {
                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), to: "", feeRate: 0, signatureScriptFunction: any())
                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                }

                it("sends transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }
            }
        }
    }
}
