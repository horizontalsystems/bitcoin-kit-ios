import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class TransactionSenderTests: QuickSpec {
    override func spec() {
        let mockTransactionSyncer = MockITransactionSyncer()
        let mockInitialBlockDownload = MockIInitialBlockDownload()
        let mockPeerManager = MockIPeerManager()
        let mockStorage = MockIStorage()
        let mockTimer = MockITransactionSendTimer()

        var sender: TransactionSender!

        let readyPeer = MockIPeer()
        let readyPeer2 = MockIPeer()
        let readyPeer3 = MockIPeer()
        let syncedPeer = MockIPeer()
        let syncedPeer2 = MockIPeer()
        let syncedReadyPeer = MockIPeer()
        let transaction = TestData.p2pkhTransaction

        beforeEach {
            stub(mockTimer) { mock in
                when(mock.startIfNotRunning()).thenDoNothing()
            }
            stub(mockStorage) { mock in
                when(mock.sentTransaction(byHash: any())).thenReturn(nil)
                when(mock.add(sentTransaction: any())).thenDoNothing()
            }

            stub(readyPeer) { mock in
                when(mock.ready.get).thenReturn(true)
                when(mock.add(task: any())).thenDoNothing()
            }
            stub(readyPeer2) { mock in
                when(mock.ready.get).thenReturn(true)
                when(mock.add(task: any())).thenDoNothing()
            }
            stub(readyPeer3) { mock in
                when(mock.ready.get).thenReturn(true)
                when(mock.add(task: any())).thenDoNothing()
            }
            stub(syncedPeer) { mock in
                when(mock.ready.get).thenReturn(false)
                when(mock.add(task: any())).thenDoNothing()
            }
            stub(syncedPeer2) { mock in
                when(mock.ready.get).thenReturn(false)
                when(mock.add(task: any())).thenDoNothing()
            }
            stub(syncedReadyPeer) { mock in
                when(mock.ready.get).thenReturn(true)
                when(mock.add(task: any())).thenDoNothing()
            }

            sender = TransactionSender(transactionSyncer: mockTransactionSyncer, initialBlockDownload: mockInitialBlockDownload, peerManager: mockPeerManager, storage: mockStorage, timer: mockTimer, queue: DispatchQueue.main)
        }

        afterEach {
            reset(mockTransactionSyncer, mockInitialBlockDownload, mockPeerManager, mockStorage, mockTimer, readyPeer, readyPeer2, syncedPeer, syncedPeer2, syncedReadyPeer)

            sender = nil
        }

        describe("#send(transaction)") {
            context("when has 1 synced and 2 ready peers") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([syncedPeer])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(3)
                        when(mock.readyPeers.get).thenReturn([readyPeer, readyPeer2])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("sends to 1 ready peers") {
                    verify(readyPeer).add(task: any())
                    verify(readyPeer2, never()).add(task: any())
                    verify(syncedPeer, never()).add(task: any())
                }
            }

            context("when has 0 synced and 2 ready peers") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(2)
                        when(mock.readyPeers.get).thenReturn([readyPeer, readyPeer2])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("doesn't send to any peer") {
                    verify(readyPeer, never()).add(task: any())
                    verify(readyPeer2, never()).add(task: any())
                }
            }

            context("when has 1 synced and 0 ready peers") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([syncedPeer])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(1)
                        when(mock.readyPeers.get).thenReturn([])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("doesn't send to any peer") {
                    verify(syncedPeer, never()).add(task: any())
                }
            }

            context("when has 1 syncedReady peer") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([syncedReadyPeer])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(1)
                        when(mock.readyPeers.get).thenReturn([syncedReadyPeer])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("doesn't send to any peer") {
                    verify(syncedReadyPeer, never()).add(task: any())
                }
            }

            context("when has 1 synced and 1 ready peers") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([syncedPeer])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(2)
                        when(mock.readyPeers.get).thenReturn([readyPeer])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("sends to the ready peer") {
                    verify(readyPeer).add(task: any())
                    verify(syncedPeer, never()).add(task: any())
                }
            }

            context("when has 1 syncedAndReady and 1 synced peers") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([syncedPeer, syncedReadyPeer])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(2)
                        when(mock.readyPeers.get).thenReturn([syncedReadyPeer])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("sends to the syncedAndReady peer") {
                    verify(syncedReadyPeer).add(task: any())
                    verify(syncedPeer, never()).add(task: any())
                }
            }

            context("when has 1 syncedAndReady and 1 ready peers") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([syncedReadyPeer])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(2)
                        when(mock.readyPeers.get).thenReturn([readyPeer])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("sends to the ready peer") {
                    verify(readyPeer).add(task: any())
                    verify(syncedReadyPeer, never()).add(task: any())
                }
            }

            context("when has 2 synced 1 syncedAndReady and 3 ready peers") {
                beforeEach {
                    stub(mockInitialBlockDownload) { mock in
                        when(mock.syncedPeers.get).thenReturn([syncedPeer, syncedPeer2, syncedReadyPeer])
                    }
                    stub(mockPeerManager) { mock in
                        when(mock.totalPeersCount.get).thenReturn(6)
                        when(mock.readyPeers.get).thenReturn([readyPeer, readyPeer2, readyPeer3, syncedReadyPeer])
                    }

                    sender.send(pendingTransaction: transaction)
                    self.waitForMainQueue()
                }

                it("sends to the ready peer") {
                    verify(readyPeer).add(task: any())
                    verify(readyPeer2).add(task: any())
                    verify(readyPeer3, never()).add(task: any())
                    verify(syncedReadyPeer, never()).add(task: any())
                    verify(syncedPeer, never()).add(task: any())
                    verify(syncedPeer2, never()).add(task: any())
                }
            }
        }
    }
}
