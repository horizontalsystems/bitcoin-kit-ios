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

        var transactionCreator: TransactionCreator!
        let transaction = TestData.p2pkhTransaction

        afterEach {
            reset(mockTransactionBuilder, mockTransactionProcessor, mockTransactionSender)
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

                transactionCreator = TransactionCreator(transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, transactionSender: mockTransactionSender)
            }

            context("when error") {
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
