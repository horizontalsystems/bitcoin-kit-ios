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

        let transaction = TestData.p2pkhTransaction

        let toAddress = "toAddressPKH"
        let sendingValue = 100_000_000
        let feeRate = 1000
        let senderPay = true

        var creator: TransactionCreator!

        beforeEach {
            stub(mockTransactionBuilder) { mock in
                when(mock.buildTransaction(toAddress: any(), value: any(), feeRate: any(), senderPay: any(), pluginData: any())).thenReturn(transaction)
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

            creator = TransactionCreator(transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, transactionSender: mockTransactionSender, bloomFilterManager: mockBloomFilterManager)
        }

        afterEach {
            reset(mockTransactionBuilder, mockTransactionProcessor, mockTransactionSender, mockBloomFilterManager)
            creator = nil
        }

        describe("#create(to:value:feeRate:senderPay:)") {
            context("when all valid") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }
                    _ = try! creator.create(to: toAddress, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("creates transaction") {
                    verify(mockTransactionBuilder).buildTransaction(toAddress: toAddress, value: sendingValue, feeRate: feeRate, senderPay: senderPay, pluginData: any())
                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                }

                it("sends transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }
            }

            context("when BloomFilterManager.BloomFilterExpired error") {
                beforeEach {
                    stub(mockTransactionProcessor) { mock in
                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try? creator.create(to: toAddress, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("does create transaction") {
                    verify(mockTransactionBuilder).buildTransaction(toAddress: toAddress, value: sendingValue, feeRate: feeRate, senderPay: senderPay, pluginData: any())
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

                    _ = try? creator.create(to: toAddress, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("doesn't create transaction") {
                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
                }

                it("doesn't regenerate bloomfilter") {
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }
        }

        describe("#create(from:to:feeRate:)") {
            let unspentOutput = UnspentOutput(output: TestData.p2shTransaction.outputs[0], publicKey: TestData.pubKey(), transaction: Transaction(), blockHeight: nil)

            beforeEach {
                stub(mockTransactionBuilder) { mock in
                    when(mock).buildTransaction(from: any(), toAddress: any(), feeRate: any()).thenReturn(transaction)
                }
            }

            context("when success") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try! creator.create(from: unspentOutput, to: toAddress, feeRate: feeRate)
                }

                it("creates transaction") {
                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), toAddress: toAddress, feeRate: feeRate)
                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                }

                it("sends transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }
            }

            context("when BloomFilterManager.BloomFilterExpired error") {
                beforeEach {
                    stub(mockTransactionProcessor) { mock in
                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try! creator.create(from: unspentOutput, to: toAddress, feeRate: feeRate)
                }

                it("does create transaction") {
                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), toAddress: toAddress, feeRate: feeRate)
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

                    _ = try? creator.create(from: unspentOutput, to: toAddress, feeRate: feeRate)
                }

                it("doesn't create transaction") {
                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
                }

                it("doesn't regenerate bloomfilter") {
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }
        }
    }
}
