//import XCTest
//import Quick
//import Nimble
//import Cuckoo
//@testable import BitcoinCore
//
//class TransactionSyncerTests: QuickSpec {
//    override func spec() {
//        let mockStorage = MockIStorage()
//        let mockTransactionProcessor = MockITransactionProcessor()
//        let mockAddressManager = MockIPublicKeyManager()
//
//        var syncer: TransactionSyncer!
//
//        beforeEach {
//            stub(mockTransactionProcessor) { mock in
//                when(mock.processReceived(transactions: any(), inBlock: any(), skipCheckBloomFilter: any())).thenDoNothing()
//            }
//            stub(mockAddressManager) { mock in
//                when(mock.fillGap()).thenDoNothing()
//            }
//
//            syncer = TransactionSyncer(storage: mockStorage, processor: mockTransactionProcessor, publicKeyManager: mockAddressManager)
//        }
//
//        afterEach {
//            reset(mockStorage, mockTransactionProcessor, mockAddressManager)
//
//            syncer = nil
//        }
//
//        describe("#pendingTransactions") {
//            let fullTransaction = TestData.p2pkTransaction
//
//            context("when transaction is .new") {
//                beforeEach {
//                    stub(mockStorage) { mock in
//                        when(mock.newTransactions()).thenReturn([fullTransaction.header])
//                    }
//                }
//
//                it("returns transaction") {
//                    stub(mockStorage) { mock in
//                        when(mock.sentTransaction(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(nil)
//                        when(mock.inputs(transactionHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.inputs)
//                        when(mock.outputs(transactionHash: equal(to: fullTransaction.header.dataHash))).thenReturn(fullTransaction.outputs)
//                    }
//                    let transactions = syncer.newTransactions()
//
//                    expect(transactions.count).to(equal(1))
//                    expect(transactions.first!.header.dataHash).to(equal(fullTransaction.header.dataHash))
//                }
//            }
//
//            context("when transaction is not new") {
//                it("doesn't return transaction") {
//                    stub(mockStorage) { mock in
//                        when(mock.newTransactions()).thenReturn([])
//                    }
//                    expect(syncer.newTransactions()).to(beEmpty())
//                }
//            }
//        }
//
//        describe("#handleRelayed(transactions:)") {
//            context("when empty array is given") {
//                it("doesn't do anything") {
//                    syncer.handleRelayed(transactions: [])
//
//                    verify(mockTransactionProcessor, never()).processReceived(transactions: any(), inBlock: any(), skipCheckBloomFilter: any())
//                    verify(mockAddressManager, never()).fillGap()
//                }
//            }
//
//            context("when not empty array is given") {
//                let transactions = [TestData.p2pkhTransaction]
//
//                context("when need to update bloom filter") {
//                    it("fills addresses gap") {
//                        stub(mockTransactionProcessor) { mock in
//                            when(mock.processReceived(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
//                        }
//
//                        syncer.handleRelayed(transactions: transactions)
//                        verify(mockTransactionProcessor).processReceived(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false))
//                        verify(mockAddressManager).fillGap()
//                    }
//                }
//
//                context("when don't need to update bloom filter") {
//                    it("doesn't run address fillGap") {
//                        stub(mockTransactionProcessor) { mock in
//                            when(mock.processReceived(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: equal(to: false))).thenDoNothing()
//                        }
//
//                        syncer.handleRelayed(transactions: transactions)
//                        verify(mockTransactionProcessor).processReceived(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false))
//                        verify(mockAddressManager, never()).fillGap()
//                    }
//                }
//
//            }
//        }
//
//        describe("#handleInvalid(transactionWithHash:)") {
//            it("calls processes invalid transaction") {
//                let fullTransaction = TestData.p2pkhTransaction
//
//                stub(mockTransactionProcessor) { mock in
//                    when(mock.processInvalid(transactionHash: equal(to: fullTransaction.header.dataHash))).thenDoNothing()
//                }
//
//                syncer.handleInvalid(fullTransaction: fullTransaction)
//                verify(mockTransactionProcessor).processInvalid(transactionHash: equal(to: fullTransaction.header.dataHash))
//            }
//        }
//
//        describe("#shouldRequestTransaction") {
//            let fullTransaction = TestData.p2wpkhTransaction
//
//            context("when relayed transaction exists") {
//                it("returns false") {
//                    stub(mockStorage) { mock in
//                        when(mock.relayedTransactionExists(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(true)
//                    }
//
//                    XCTAssertEqual(syncer.shouldRequestTransaction(hash: fullTransaction.header.dataHash), false)
//                }
//            }
//
//            context("when relayed transaction doesn't exist") {
//                it("returns true") {
//                    stub(mockStorage) { mock in
//                        when(mock.relayedTransactionExists(byHash: equal(to: fullTransaction.header.dataHash))).thenReturn(false)
//                    }
//
//                    XCTAssertEqual(syncer.shouldRequestTransaction(hash: fullTransaction.header.dataHash), true)
//                }
//            }
//        }
//    }
//}
