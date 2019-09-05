import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class TransactionSyncerTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockTransactionProcessor = MockITransactionProcessor()
        let mockAddressManager = MockIPublicKeyManager()
        let mockBloomFilterManager = MockIBloomFilterManager()
        let maxRetriesCount = 3
        let retriesPeriod: Double = 60
        let totalRetriesPeriod: Double = 60 * 60 * 24

        var syncer: TransactionSyncer!

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.add(sentTransaction: any())).thenDoNothing()
                when(mock.update(sentTransaction: any())).thenDoNothing()
            }
            stub(mockTransactionProcessor) { mock in
                when(mock.processReceived(transactions: any(), inBlock: any(), skipCheckBloomFilter: any())).thenDoNothing()
            }
            stub(mockAddressManager) { mock in
                when(mock.fillGap()).thenDoNothing()
            }
            stub(mockBloomFilterManager) { mock in
                when(mock.regenerateBloomFilter()).thenDoNothing()
            }

            syncer = TransactionSyncer(
                    storage: mockStorage, processor: mockTransactionProcessor, publicKeyManager: mockAddressManager, bloomFilterManager: mockBloomFilterManager,
                    maxRetriesCount: maxRetriesCount, retriesPeriod: retriesPeriod, totalRetriesPeriod: totalRetriesPeriod)
        }

        afterEach {
            reset(mockStorage, mockTransactionProcessor, mockAddressManager, mockBloomFilterManager)

            syncer = nil
        }

        describe("#pendingTransactions") {
            let fullTransaction = TestData.p2pkTransaction

            context("when transaction is .new") {
                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.newTransactions()).thenReturn([fullTransaction.header])
                    }
                }

                context("when it wasn't sent") {
                    it("returns transaction") {
                        stub(mockStorage) { mock in
                            when(mock.sentTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(nil)
                            when(mock.inputs(transactionHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.inputs)
                            when(mock.outputs(transactionHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.outputs)
                        }
                        let transactions = syncer.pendingTransactions()

                        expect(transactions.count).to(equal(1))
                        expect(transactions.first!.header.dataHash).to(equal(fullTransaction.header.dataHash))
                    }
                }

                context("when it was sent") {
                    let sentTransaction = SentTransaction(dataHash: fullTransaction.header.dataHash)
                    sentTransaction.lastSendTime = CACurrentMediaTime() - retriesPeriod - 1
                    sentTransaction.retriesCount = 0
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.sentTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(sentTransaction)
                        }
                    }

                    context("when sent not too many times or too frequently") {
                        it("returns transaction") {
                            stub(mockStorage) { mock in
                                when(mock.inputs(transactionHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.inputs)
                                when(mock.outputs(transactionHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.outputs)
                            }

                            let transactions = syncer.pendingTransactions()
                            expect(transactions.count).to(equal(1))
                            expect(transactions.first!.header.dataHash).to(equal(fullTransaction.header.dataHash))
                        }
                    }

                    context("when sent too many times") {
                        it("doesn't return transaction") {
                            sentTransaction.retriesCount = maxRetriesCount
                            expect(syncer.pendingTransactions()).to(beEmpty())
                        }
                    }

                    context("when sent too often") {
                        it("doesn't return transaction") {
                            sentTransaction.lastSendTime = CACurrentMediaTime()
                            expect(syncer.pendingTransactions()).to(beEmpty())
                        }
                    }

                    context("when sent too often in totalRetriesPeriod period") {
                        it("doesn't return transaction") {
                            sentTransaction.firstSendTime = CACurrentMediaTime() - totalRetriesPeriod - 1
                            expect(syncer.pendingTransactions()).to(beEmpty())
                        }
                    }
                }
            }

            context("when transaction is not new") {
                it("doesn't return transaction") {
                    stub(mockStorage) { mock in
                        when(mock.newTransactions()).thenReturn([])
                    }
                    expect(syncer.pendingTransactions()).to(beEmpty())
                }
            }
        }

        describe("#handle(sentTransaction:)") {
            let fullTransaction = TestData.p2pkhTransaction

            context("when SentTransaction does not exist") {
                it("adds new SentTransaction object") {
                    stub(mockStorage) { mock in
                        when(mock.newTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.header)
                        when(mock.sentTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(nil)
                    }

                    syncer.handle(sentTransaction: fullTransaction)

                    let argumentCaptor = ArgumentCaptor<SentTransaction>()
                    verify(mockStorage).add(sentTransaction: argumentCaptor.capture())
                    let sentTransaction = argumentCaptor.value!

                    expect(sentTransaction.dataHash).to(equal(fullTransaction.header.dataHash))
                }
            }

            context("when SentTransaction exists") {
                var sentTransaction = SentTransaction(dataHash: fullTransaction.header.dataHash)
                sentTransaction.firstSendTime = sentTransaction.firstSendTime - 100
                sentTransaction.lastSendTime = sentTransaction.lastSendTime - 100

                it("updates existing SentTransaction object") {
                    stub(mockStorage) { mock in
                        when(mock.newTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.header)
                        when(mock.sentTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(sentTransaction)
                    }

                    syncer.handle(sentTransaction: fullTransaction)

                    let argumentCaptor = ArgumentCaptor<SentTransaction>()
                    verify(mockStorage).update(sentTransaction: argumentCaptor.capture())
                    sentTransaction = argumentCaptor.value!

                    expect(sentTransaction.dataHash).to(equal(fullTransaction.header.dataHash))
                }
            }

            context("when Transaction doesn't exist") {
                it("neither adds new nor updates existing") {
                    stub(mockStorage) { mock in
                        when(mock.newTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(nil)
                    }

                    syncer.handle(sentTransaction: fullTransaction)

                    verify(mockStorage, never()).add(sentTransaction: any())
                    verify(mockStorage, never()).update(sentTransaction: any())
                }
            }
        }

        describe("#handle(transactions:)") {
            context("when empty array is given") {
                it("doesn't do anything") {
                    syncer.handle(transactions: [])

                    verify(mockTransactionProcessor, never()).processReceived(transactions: any(), inBlock: any(), skipCheckBloomFilter: any())
                    verify(mockAddressManager, never()).fillGap()
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }

            context("when not empty array is given") {
                let transactions = [TestData.p2pkhTransaction]

                context("when need to update bloom filter") {
                    it("fills addresses gap and regenerates bloom filter") {
                        stub(mockTransactionProcessor) { mock in
                            when(mock.processReceived(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                        }

                        syncer.handle(transactions: transactions)
                        verify(mockTransactionProcessor).processReceived(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false))
                        verify(mockAddressManager).fillGap()
                        verify(mockBloomFilterManager).regenerateBloomFilter()
                    }
                }

                context("when don't need to update bloom filter") {
                    it("doesn't run address fillGap and doesn't regenerate bloom filter") {
                        stub(mockTransactionProcessor) { mock in
                            when(mock.processReceived(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: equal(to: false))).thenDoNothing()
                        }

                        syncer.handle(transactions: transactions)
                        verify(mockTransactionProcessor).processReceived(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false))
                        verify(mockAddressManager, never()).fillGap()
                        verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                    }
                }

            }
        }
        
        describe("#shouldRequestTransaction") {
            let fullTransaction = TestData.p2wpkhTransaction

            context("when relayed transaction exists") {
                it("returns false") {
                    stub(mockStorage) { mock in
                        when(mock.relayedTransactionExists(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(true)
                    }

                    XCTAssertEqual(syncer.shouldRequestTransaction(hash: fullTransaction.header.dataHash), false)
                }
            }

            context("when relayed transaction doesn't exist") {
                it("returns true") {
                    stub(mockStorage) { mock in
                        when(mock.relayedTransactionExists(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(false)
                    }

                    XCTAssertEqual(syncer.shouldRequestTransaction(hash: fullTransaction.header.dataHash), true)
                }
            }
        }
    }
}
