import XCTest
import Quick
import Nimble
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionSyncerTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockTransactionProcessor = MockITransactionProcessor()
        let mockAddressManager = MockIAddressManager()
        let mockBloomFilterManager = MockIBloomFilterManager()
        let maxRetriesCount = 3
        let retriesPeriod: Double = 60
        let totalRetriesPeriod: Double = 60 * 60 * 24

        var realm: Realm!
        var syncer: TransactionSyncer!

        beforeEach {
            realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
            try! realm.write {
                realm.deleteAll()
            }

            stub(mockStorage) { mock in
                when(mock.inTransaction(_: any())).then({ try? $0(realm) })
                when(mock.add(sentTransaction: any())).thenDoNothing()
                when(mock.update(sentTransaction: any())).thenDoNothing()
            }
            stub(mockTransactionProcessor) { mock in
                when(mock.process(transactions: any(), inBlock: any(), skipCheckBloomFilter: any(), realm: any())).thenDoNothing()
            }
            stub(mockAddressManager) { mock in
                when(mock.fillGap()).thenDoNothing()
            }
            stub(mockBloomFilterManager) { mock in
                when(mock.regenerateBloomFilter()).thenDoNothing()
            }

            syncer = TransactionSyncer(
                    storage: mockStorage, processor: mockTransactionProcessor, addressManager: mockAddressManager, bloomFilterManager: mockBloomFilterManager,
                    maxRetriesCount: maxRetriesCount, retriesPeriod: retriesPeriod, totalRetriesPeriod: totalRetriesPeriod)
        }

        afterEach {
            reset(mockStorage, mockTransactionProcessor, mockAddressManager, mockBloomFilterManager)

            realm = nil
            syncer = nil
        }

        describe("#pendingTransactions") {
            let transaction = TestData.p2pkTransaction

            context("when transaction is .new") {
                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.newTransactions()).thenReturn([transaction])
                    }
                }

                context("when it wasn't sent") {
                    it("returns transaction") {
                        stub(mockStorage) { mock in
                            when(mock.sentTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(nil)
                        }
                        let transactions = syncer.pendingTransactions()

                        expect(transactions.count).to(equal(1))
                        expect(transactions.first!.dataHash).to(equal(transaction.dataHash))
                    }
                }

                context("when it was sent") {
                    let sentTransaction = SentTransaction(reversedHashHex: transaction.reversedHashHex)
                    sentTransaction.lastSendTime = CACurrentMediaTime() - retriesPeriod - 1
                    sentTransaction.retriesCount = 0
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.sentTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(sentTransaction)
                        }
                    }

                    context("when sent not too many times or too frequently") {
                        it("returns transaction") {
                            let transactions = syncer.pendingTransactions()
                            expect(transactions.count).to(equal(1))
                            expect(transactions.first!.dataHash).to(equal(transaction.dataHash))
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
            let transaction = TestData.p2pkhTransaction

            context("when SentTransaction does not exist") {
                it("adds new SentTransaction object") {
                    stub(mockStorage) { mock in
                        when(mock.newTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(transaction)
                        when(mock.sentTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(nil)
                    }

                    syncer.handle(sentTransaction: transaction)

                    let argumentCaptor = ArgumentCaptor<SentTransaction>()
                    verify(mockStorage).add(sentTransaction: argumentCaptor.capture())
                    let sentTransaction = argumentCaptor.value!

                    expect(sentTransaction.reversedHashHex).to(equal(transaction.reversedHashHex))
                }
            }

            context("when SentTransaction exists") {
                var sentTransaction = SentTransaction(reversedHashHex: transaction.reversedHashHex)
                sentTransaction.firstSendTime = sentTransaction.firstSendTime - 100
                sentTransaction.lastSendTime = sentTransaction.lastSendTime - 100

                it("updates existing SentTransaction object") {
                    stub(mockStorage) { mock in
                        when(mock.newTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(transaction)
                        when(mock.sentTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(sentTransaction)
                    }

                    syncer.handle(sentTransaction: transaction)

                    let argumentCaptor = ArgumentCaptor<SentTransaction>()
                    verify(mockStorage).update(sentTransaction: argumentCaptor.capture())
                    sentTransaction = argumentCaptor.value!

                    expect(sentTransaction.reversedHashHex).to(equal(transaction.reversedHashHex))
                }
            }

            context("when Transaction doesn't exist") {
                it("neither adds new nor updates existing") {
                    stub(mockStorage) { mock in
                        when(mock.newTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(nil)
                    }

                    syncer.handle(sentTransaction: transaction)

                    verify(mockStorage, never()).add(sentTransaction: any())
                    verify(mockStorage, never()).update(sentTransaction: any())
                }
            }
        }

        describe("#handle(transactions:)") {
            context("when empty array is given") {
                it("doesn't do anything") {
                    syncer.handle(transactions: [])

                    verify(mockTransactionProcessor, never()).process(transactions: any(), inBlock: any(), skipCheckBloomFilter: any(), realm: any())
                    verify(mockAddressManager, never()).fillGap()
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }

            context("when not empty array is given") {
                let transactions = [TestData.p2pkhTransaction]

                context("when need to update bloom filter") {
                    it("fills addresses gap and regenerates bloom filter") {
                        stub(mockTransactionProcessor) { mock in
                            when(mock.process(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: any(), realm: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                        }

                        syncer.handle(transactions: transactions)
                        verify(mockTransactionProcessor).process(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false), realm: any())
                        verify(mockAddressManager).fillGap()
                        verify(mockBloomFilterManager).regenerateBloomFilter()
                    }
                }

                context("when don't need to update bloom filter") {
                    it("doesn't run address fillGap and doesn't regenerate bloom filter") {
                        stub(mockTransactionProcessor) { mock in
                            when(mock.process(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: equal(to: false), realm: any())).thenDoNothing()
                        }

                        syncer.handle(transactions: transactions)
                        verify(mockTransactionProcessor).process(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false), realm: any())
                        verify(mockAddressManager, never()).fillGap()
                        verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                    }
                }

            }
        }
        
        describe("#shouldRequestTransaction") {
            let transaction = TestData.p2wpkhTransaction

            context("when relayed transaction exists") {
                it("returns false") {
                    stub(mockStorage) { mock in
                        when(mock.relayedTransactionExists(byReversedHashHex: transaction.reversedHashHex)).thenReturn(true)
                    }

                    XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), false)
                }
            }

            context("when relayed transaction doesn't exist") {
                it("returns true") {
                    stub(mockStorage) { mock in
                        when(mock.relayedTransactionExists(byReversedHashHex: transaction.reversedHashHex)).thenReturn(false)
                    }

                    XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), true)
                }
            }
        }
    }
}
