import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore
@testable import DashKit

class InstantSendTests: QuickSpec {

    override func spec() {
        let mockTransactionSyncer = MockIDashTransactionSyncer()
        let mockTransactionLockVoteHandler = MockITransactionLockVoteHandler()
        let mockInstantSendLockHandler = MockIInstantSendLockHandler()
        let instantSend = InstantSend(transactionSyncer: mockTransactionSyncer, transactionLockVoteHandler: mockTransactionLockVoteHandler, instantSendLockHandler: mockInstantSendLockHandler, dispatchQueue: DispatchQueue.main)

        beforeEach {
            stub(mockTransactionSyncer) { mock in
                when(mock.handle(transactions: any())).thenDoNothing()
            }
        }

        afterEach {
            reset(mockInstantSendLockHandler, mockTransactionLockVoteHandler, mockTransactionSyncer)
        }

        describe("#handle(insertedTxHash: Data)") {
            it("calls instant send lock handler") {
                let txHash = Data(repeating: 0x01, count: 2)
                stub(mockInstantSendLockHandler) { mock in
                    when(mock.handle(transactionHash: equal(to: txHash))).thenDoNothing()
                }
                instantSend.handle(insertedTxHash: txHash)
                verify(mockInstantSendLockHandler).handle(transactionHash: equal(to: txHash))
            }
        }
        describe("#handleCompletedTask(peer: IPeer, task: PeerTask") {
            let mockPeer = MockIDashPeer()

            describe("when task is not instant") {
                it("ignores it") {
                    let task = PeerTask()
                    let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)

                    expect(handled).to(equal(false))
                }
            }

            context("when task is RequestTransactionLockRequestsTask") {
                context("when transactions is empty") {
                    it("send empty array to transaction syncer and return true") {
                        let task = RequestTransactionLockRequestsTask(hashes: [])

                        stub(mockTransactionSyncer) { mock in
                            when(mock.handle(transactions: equal(to: []))).thenDoNothing()
                        }
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        verify(mockTransactionSyncer).handle(transactions: equal(to: []))
                        expect(handled).to(equal(true))

                        verify(mockTransactionLockVoteHandler, never()).handle(transaction: any())
                    }
                    it("send some elements to syncer, call for each handler and return true") {
                        let task = RequestTransactionLockRequestsTask(hashes: [])
                        task.transactions.append(DashTestData.transaction)
                        task.transactions.append(DashTestData.transaction)

                        stub(mockTransactionSyncer) { mock in
                            when(mock.handle(transactions: equal(to: [DashTestData.transaction, DashTestData.transaction]))).thenDoNothing()
                        }
                        stub(mockTransactionLockVoteHandler) { mock in
                            when(mock.handle(transaction: equal(to: DashTestData.transaction))).thenDoNothing()
                        }
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        verify(mockTransactionSyncer).handle(transactions: equal(to: [DashTestData.transaction, DashTestData.transaction]))
                        expect(handled).to(equal(true))

                        verify(mockTransactionLockVoteHandler, times(2)).handle(transaction: equal(to: DashTestData.transaction))
                    }
                }
            }
            context("when task is RequestTransactionLockVotesTask") {
                context("when lockVotes is empty") {
                    it("return true") {
                        let task = RequestTransactionLockVotesTask(hashes: [])

                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        expect(handled).to(equal(true))
                        verify(mockTransactionLockVoteHandler, never()).handle(lockVote: any())
                    }
                    it("call for each handler and return true") {
                        let task = RequestTransactionLockVotesTask(hashes: [])
                        let lockVote = DashTestData.transactionLockVote(hash: Data(repeating: 0x01, count: 2))
                        task.transactionLockVotes.append(lockVote)
                        task.transactionLockVotes.append(lockVote)

                        stub(mockTransactionLockVoteHandler) { mock in
                            when(mock.handle(lockVote: equal(to: lockVote))).thenDoNothing()
                        }
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        expect(handled).to(equal(true))

                        verify(mockTransactionLockVoteHandler, times(2)).handle(lockVote: equal(to: lockVote))
                    }
                }
            }
            context("when task is RequestLlmqInstantLocksTask") {
                context("when locks is empty") {
                    it("return true") {
                        let task = RequestLlmqInstantLocksTask(hashes: [])

                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        expect(handled).to(equal(true))
                        verify(mockInstantSendLockHandler, never()).handle(isLock: any())
                    }
                    it("call for each handler and return true") {
                        let task = RequestLlmqInstantLocksTask(hashes: [])
                        let isLock = ISLockMessage(inputs: [], txHash: Data(), sign: Data(), hash: Data(repeating: 0x01, count: 2))
                        task.llmqInstantLocks.append(isLock)
                        task.llmqInstantLocks.append(isLock)

                        stub(mockInstantSendLockHandler) { mock in
                            when(mock.handle(isLock: equal(to: isLock))).thenDoNothing()
                        }
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        expect(handled).to(equal(true))

                        verify(mockInstantSendLockHandler, times(2)).handle(isLock: equal(to: isLock))
                    }
                }
            }
        }
    }
}
