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
        let mockLockVoteManager = MockITransactionLockVoteManager()
        let mockInstantTransactionManager = MockIInstantTransactionManager()
        var instantSend: InstantSend!

        beforeEach {
            stub(mockTransactionSyncer) { mock in
                when(mock.handle(transactions: any())).thenDoNothing()
            }
            instantSend = InstantSend(transactionSyncer: mockTransactionSyncer, lockVoteManager: mockLockVoteManager, instantTransactionManager: mockInstantTransactionManager, dispatchQueue: DispatchQueue.main)
        }

        afterEach {
            reset(mockInstantTransactionManager, mockLockVoteManager, mockTransactionSyncer)
            instantSend = nil
        }

        describe("#handleCompletedTask(peer:, task:)") {
            let mockPeer = MockIDashPeer()

            describe("when task is not instant") {
                it("ignores it") {
                    let task = PeerTask()
                    let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)

                    expect(handled).to(equal(false))
                }
            }

            describe("when task is transaction ix") {
                let task = RequestTransactionLockRequestsTask(hashes: [])
                let transactions = [DashTestData.transaction]
                task.transactions = transactions
                let inputTxHash = transactions[0].inputs[0].previousOutputTxHash
                let txHash = transactions[0].header.dataHash

                let instantInputs = [InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 0, blockHeight: nil)]
                let lockVotes = [DashTestData.transactionLockVote(txHash: txHash, inputTxHash: inputTxHash)]

                beforeEach {
                    stub(mockLockVoteManager) { mock in
                        when(mock.validate(lockVote: equal(to: lockVotes[0]))).thenDoNothing()
                    }
                    stub(mockInstantTransactionManager) { mock in
                        when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transactions[0]))).thenReturn(instantInputs)
                    }
                }

                describe("when relayed lock votes is empty") {
                    beforeEach {
                        stub(mockLockVoteManager) { mock in
                            when(mock.takeRelayedLockVotes(for: equal(to: txHash))).thenReturn([])
                        }
                    }

                    it("handles transaction ix task") {
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        verify(mockTransactionSyncer).handle(transactions: equal(to: transactions))
                        verify(mockInstantTransactionManager).instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transactions[0]))
                        verify(mockLockVoteManager).takeRelayedLockVotes(for: equal(to: transactions[0].header.dataHash))

                        verifyNoMoreInteractions(mockLockVoteManager)
                        expect(handled).to(equal(true))
                    }
                }
                describe("when relayed lock votes is not empty") {
                    beforeEach {
                        stub(mockInstantTransactionManager) { mock in
                            when(mock.instantTransactionInputs(for: any(), instantTransaction: any())).thenReturn(instantInputs)
                            when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(true)
                            when(mock.updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))).thenDoNothing()

                        }
                        stub(mockLockVoteManager) { mock in
                            when(mock.add(checked: equal(to: lockVotes[0]))).thenDoNothing()
                            when(mock.takeRelayedLockVotes(for: equal(to: txHash))).thenReturn(lockVotes)
                        }
                    }

                    it("handles transaction ix task with valid lock vote") {
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        verify(mockTransactionSyncer).handle(transactions: equal(to: transactions))
                        verify(mockInstantTransactionManager).instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transactions[0]))
                        verify(mockLockVoteManager).takeRelayedLockVotes(for: equal(to: transactions[0].header.dataHash))

                        verify(mockLockVoteManager).add(checked: equal(to: lockVotes[0]))
                        verify(mockLockVoteManager).validate(lockVote: equal(to: lockVotes[0]))
                        verify(mockInstantTransactionManager).updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))
                        expect(handled).to(equal(true))
                    }

                    it("stops working when instant input vote count >= 6") {
                        let instantInputs = [InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 6, blockHeight: nil)]
                        stub(mockInstantTransactionManager) { mock in
                            when(mock.instantTransactionInputs(for: any(), instantTransaction: any())).thenReturn(instantInputs)
                        }
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        verify(mockTransactionSyncer).handle(transactions: equal(to: transactions))
                        verify(mockInstantTransactionManager).instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transactions[0]))
                        verify(mockLockVoteManager).takeRelayedLockVotes(for: equal(to: transactions[0].header.dataHash))

                        verify(mockLockVoteManager).add(checked: equal(to: lockVotes[0]))
                        verify(mockLockVoteManager, never()).validate(lockVote: equal(to: lockVotes[0]))
                        expect(handled).to(equal(true))
                    }

                    describe("when lock vote is valid") {
                        it("increased vote count and return instant tx status") {
                            stub(mockLockVoteManager) { mock in
                                when(mock.takeRelayedLockVotes(for: any())).thenReturn(lockVotes)
                            }
                            let _ = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                            self.waitForMainQueue()

                            verify(mockInstantTransactionManager).updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))
                            verify(mockInstantTransactionManager).isTransactionInstant(txHash: equal(to: txHash))
                        }
                    }
                    describe("when lock vote is invalid") {
                        beforeEach {
                            stub(mockLockVoteManager) { mock in
                                when(mock.validate(lockVote: equal(to: lockVotes[0]))).thenThrow(DashKitErrors.LockVoteValidation.masternodeNotFound)
                            }
                        }
                        it("fails and stop work") {
                            let _ = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                            self.waitForMainQueue()

                            verify(mockInstantTransactionManager, never()).isTransactionInstant(txHash: any())
                        }
                    }
                }
            }
            describe("when task is lockVote") {
                let transaction = DashTestData.transaction
                let txHash = transaction.header.dataHash
                let inputTxHash = transaction.inputs[0].previousOutputTxHash
                let lvHash = txHash + inputTxHash
                let lockVotes = [DashTestData.transactionLockVote(txHash: txHash, inputTxHash: inputTxHash, hash: lvHash)]

                let task = RequestTransactionLockVotesTask(hashes: [])
                task.transactionLockVotes = lockVotes

                let instantInputs = [InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 0, blockHeight: nil)]

                beforeEach {
                    stub(mockLockVoteManager) { mock in
                        when(mock.processed(lvHash: equal(to: lvHash))).thenReturn(false)
                    }

                }
                describe("when lockVote in processed") {
                    it("stops working and returns true") {
                        stub(mockLockVoteManager) { mock in
                            when(mock.processed(lvHash: equal(to: lvHash))).thenReturn(true)
                        }
                        let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                        self.waitForMainQueue()

                        verify(mockLockVoteManager).processed(lvHash: equal(to: lvHash))
                        expect(handled).to(equal(true))
                    }
                }
                describe("when lockVote is not processed") {
                    beforeEach {
                        stub(mockLockVoteManager) { mock in
                            when(mock.processed(lvHash: equal(to: lvHash))).thenReturn(false)
                        }
                    }
                    describe("when it can't get instant inputs for lockvote") {
                        it("adds lockVote to relayed and returns true") {
                            stub(mockLockVoteManager) { mock in
                                when(mock.add(relayed: equal(to: lockVotes[0]))).thenDoNothing()
                            }
                            stub(mockInstantTransactionManager) { mock in
                                when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))).thenReturn([])
                            }
                            let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                            self.waitForMainQueue()

                            verify(mockInstantTransactionManager).instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))
                            verify(mockLockVoteManager).add(relayed: equal(to: lockVotes[0]))
                            verify(mockLockVoteManager, never()).add(checked: equal(to: lockVotes[0]))
                            expect(handled).to(equal(true))
                        }
                    }
                    describe("when get inputs for lockvote") {
                        beforeEach {
                            stub(mockInstantTransactionManager) { mock in
                                when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))).thenReturn(instantInputs)
                            }
                            stub(mockLockVoteManager) { mock in
                                when(mock.add(checked: equal(to: lockVotes[0]))).thenDoNothing()
                                when(mock.validate(lockVote: equal(to: lockVotes[0]))).thenDoNothing()
                            }
                        }
                        describe("when lockVote not validated") {
                            it("adds to checked and stops work") {
                                stub(mockLockVoteManager) { mock in
                                    when(mock.validate(lockVote: equal(to: lockVotes[0]))).thenThrow(DashKitErrors.LockVoteValidation.masternodeNotFound)
                                }
                                let _ = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                                self.waitForMainQueue()

                                verify(mockLockVoteManager).add(checked: equal(to: lockVotes[0]))
                                verify(mockLockVoteManager).validate(lockVote: equal(to: lockVotes[0]))

                                verify(mockInstantTransactionManager, never()).isTransactionInstant(txHash: equal(to: txHash))
                            }
                            describe("when lockVote is validated") {
                                beforeEach {
                                    stub(mockLockVoteManager) { mock in
                                        when(mock.validate(lockVote: equal(to: lockVotes[0]))).thenDoNothing()
                                    }
                                    stub(mockInstantTransactionManager) { mock in
                                        when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(true)
                                        when(mock.updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))).thenDoNothing()
                                    }
                                }
                                it("increases vote count and checks transaction is instant") {
                                    let handled = instantSend.handleCompletedTask(peer: mockPeer, task: task)
                                    self.waitForMainQueue()

                                    verify(mockLockVoteManager).add(checked: equal(to: lockVotes[0]))
                                    verify(mockLockVoteManager).validate(lockVote: equal(to: lockVotes[0]))

                                    verify(mockInstantTransactionManager).updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))
                                    verify(mockInstantTransactionManager).isTransactionInstant(txHash: equal(to: txHash))
                                    expect(handled).to(equal(true))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
