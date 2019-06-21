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

        describe("#create") {
            beforeEach {
                stub(mockTransactionBuilder) { mock in
                    when(mock.buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any())).thenReturn(transaction)
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

                    try? transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false)
                }

                it("does create transaction") {
                    verify(mockTransactionBuilder).buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any())
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

                    try? transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false)
                }

                it("doesn't create transaction") {
                    verify(mockTransactionBuilder, never()).buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any())
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

                    try! transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false)
                }

                it("creates transaction") {
                    verify(mockTransactionBuilder).buildTransaction(value: 0, feeRate: 0, senderPay: false, toAddress: "")
                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                }

                it("sends transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }
            }
        }
    }
}
