import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore
@testable import DashKit

class TransactionLockVoteHandlerTests: QuickSpec {

    override func spec() {
        let mockInstantTransactionDelegate = MockIInstantTransactionDelegate()
        let mockLockVoteManager = MockITransactionLockVoteManager()
        let mockInstantTransactionManager = MockIInstantTransactionManager()

        let handler = TransactionLockVoteHandler(instantTransactionManager: mockInstantTransactionManager, lockVoteManager: mockLockVoteManager, requiredVoteCount: 2)
        handler.delegate = mockInstantTransactionDelegate

        afterEach {
            reset(mockInstantTransactionManager, mockLockVoteManager, mockInstantTransactionDelegate)
        }

        let transaction = DashTestData.transaction
        let txHash = transaction.header.dataHash
        let inputTxHash = transaction.inputs[0].previousOutputTxHash
        let voteHash = Data(repeating: 0x01, count: 2)
        let lockVote = DashTestData.transactionLockVote(txHash: txHash, inputTxHash: inputTxHash, hash: voteHash)

        let otherHash = Data(hex: "0123")!
        let otherLockVote = DashTestData.transactionLockVote(txHash: otherHash, inputTxHash: otherHash, hash: otherHash)


        let instantInputs = [
            InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 0, blockHeight: nil),
        ]


        describe("#handle(transaction: FullTransaction)") {
            context("when transaction already instant") {
                it("stops processing") {
                    stub(mockInstantTransactionManager) { mock in
                        when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(true)
                    }
                    handler.handle(transaction: transaction)
                    verify(mockInstantTransactionManager).isTransactionInstant(txHash: equal(to: transaction.header.dataHash))
                    // check stops
                    verify(mockInstantTransactionManager, never()).instantTransactionInputs(for: any(), instantTransaction: any())
                }
                context("when transaction not instant") {
                    beforeEach {
                        stub(mockInstantTransactionManager) { mock in
                            when(mock.isTransactionInstant(txHash: equal(to: transaction.header.dataHash))).thenReturn(false)
                        }
                    }
                    context("when get empty relayed votes") {
                        it("stops processing") {
                            stub(mockInstantTransactionManager) { mock in
                                when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transaction))).thenReturn([])
                            }
                            stub(mockLockVoteManager) { mock in
                                when(mock.takeRelayedLockVotes(for: equal(to: txHash))).thenReturn([])
                            }
                            handler.handle(transaction: transaction)
                            verify(mockLockVoteManager).takeRelayedLockVotes(for: equal(to: txHash))
                            //check stops
                            verify(mockLockVoteManager, never()).add(checked: any())
                        }
                    }
                    context("when get some votes") {
                        beforeEach {
                            stub(mockLockVoteManager) { mock in
                                when(mock.add(checked: equal(to: otherLockVote))).thenDoNothing()
                            }
                            stub(mockInstantTransactionManager) { mock in
                                when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transaction))).thenReturn(instantInputs)
                            }
                        }
                        context("when instantInputs has't input for txHash") {
                            it("adds lockVote to checked and stops processing") {
                                stub(mockLockVoteManager) { mock in
                                    when(mock.takeRelayedLockVotes(for: equal(to: txHash))).thenReturn([otherLockVote])
                                }
                                handler.handle(transaction: transaction)
                                verify(mockLockVoteManager).add(checked: any())
                                //check stops
                                verify(mockLockVoteManager, never()).validate(lockVote: any())
                            }
                        }
                        context("when has input for txHash") {
                            beforeEach {
                                stub(mockLockVoteManager) { mock in
                                    when(mock.takeRelayedLockVotes(for: equal(to: txHash))).thenReturn([lockVote])
                                    when(mock.add(checked: equal(to: lockVote))).thenDoNothing()
                                }
                            }
                            context("when input vote count equal or more needed") {
                                it("stops processing with equal") {
                                    let input = InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 2, blockHeight: nil)
                                    stub(mockInstantTransactionManager) { mock in
                                        when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transaction))).thenReturn([input])
                                    }
                                    handler.handle(transaction: transaction)

                                    //check stops
                                    verify(mockLockVoteManager, never()).validate(lockVote: any())
                                }
                                it("stops processing with more") {
                                    let input = InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 5, blockHeight: nil)
                                    stub(mockInstantTransactionManager) { mock in
                                        when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: transaction))).thenReturn([input])
                                    }
                                    handler.handle(transaction: transaction)

                                    //check stops
                                    verify(mockLockVoteManager, never()).validate(lockVote: any())
                                }
                            }
                            context("when input has right parameters") {
                                context("when validation catch error") {
                                    beforeEach {
                                        stub(mockLockVoteManager) { mock in
                                            when(mock.validate(lockVote: equal(to: lockVote))).thenThrow(DashKitErrors.LockVoteValidation.signatureNotValid)
                                        }
                                    }
                                    it("stops processing") {
                                        handler.handle(transaction: transaction)

                                        verify(mockLockVoteManager).validate(lockVote: equal(to: lockVote))
                                        //check stops
                                        verify(mockInstantTransactionManager, never()).updateInput(for: any(), transactionInputs: any())
                                    }
                                }
                                context("when validation success") {
                                    beforeEach {
                                        stub(mockLockVoteManager) { mock in
                                            when(mock.validate(lockVote: equal(to: lockVote))).thenDoNothing()
                                        }
                                        stub(mockInstantTransactionManager) { mock in
                                            when(mock.updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))).thenDoNothing()
                                        }
                                    }
                                    context("when transaction is not instant") {
                                        it("updates inputs and stops processing") {
                                            stub(mockInstantTransactionManager) { mock in
                                                when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(false)
                                            }
                                            handler.handle(transaction: transaction)

                                            verify(mockLockVoteManager).validate(lockVote: equal(to: lockVote))
                                            verify(mockInstantTransactionManager).updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))
                                            // call before handling vote and after to check new status
                                            verify(mockInstantTransactionManager, times(2)).isTransactionInstant(txHash: equal(to: txHash))
                                            //check stops
                                            verify(mockInstantTransactionDelegate, never()).onUpdateInstant(transactionHash: equal(to: txHash))
                                        }
                                        context("when transaction become instant") {
                                            it("call delegate update instant") {
                                                stub(mockInstantTransactionManager) { mock in
                                                    when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(false).thenReturn(true)
                                                }
                                                stub(mockInstantTransactionDelegate) { mock in
                                                    when(mock.onUpdateInstant(transactionHash: equal(to: txHash))).thenDoNothing()
                                                }
                                                handler.handle(transaction: transaction)

                                                // call before handling vote and after to check new status
                                                verify(mockInstantTransactionManager, times(2)).isTransactionInstant(txHash: equal(to: txHash))
                                                //check stops
                                                verify(mockInstantTransactionDelegate).onUpdateInstant(transactionHash: equal(to: txHash))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        describe("#handle(lockVote: TraansactionLockVoteMessage)") {
            context("when transaction already instant") {
                it("stops processing") {
                    stub(mockInstantTransactionManager) { mock in
                        when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(true)
                    }
                    handler.handle(lockVote: lockVote)
                    verify(mockInstantTransactionManager).isTransactionInstant(txHash: equal(to: transaction.header.dataHash))
                    // check stops
                    verify(mockInstantTransactionManager, never()).instantTransactionInputs(for: any(), instantTransaction: any())
                }
                context("when transaction not instant") {
                    beforeEach {
                        stub(mockInstantTransactionManager) { mock in
                            when(mock.isTransactionInstant(txHash: equal(to: transaction.header.dataHash))).thenReturn(false)
                        }
                    }
                    context("when lockVote already processed") {
                        it("stops processing") {
                            stub(mockLockVoteManager) { mock in
                                when(mock.processed(lvHash: equal(to: voteHash))).thenReturn(true)
                            }
                            handler.handle(lockVote: lockVote)

                            //check stops
                            verify(mockLockVoteManager).processed(lvHash: equal(to: voteHash))
                            verify(mockInstantTransactionManager, never()).instantTransactionInputs(for: any(), instantTransaction: any())
                        }
                    }
                    context("when lockVote not processed") {
                        beforeEach {
                            stub(mockLockVoteManager) { mock in
                                when(mock.processed(lvHash: equal(to: voteHash))).thenReturn(false)
                            }
                        }
                        context("when inputs is empty") {
                            it("adds lockVote to relayed and stops processing") {
                                stub(mockInstantTransactionManager) { mock in
                                    when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))).thenReturn([])
                                }
                                stub(mockLockVoteManager) { mock in
                                    when(mock.add(relayed: equal(to: lockVote))).thenDoNothing()
                                }
                                handler.handle(lockVote: lockVote)

                                //check stops
                                verify(mockInstantTransactionManager).instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))
                                verify(mockLockVoteManager).add(relayed: equal(to: lockVote))
                                verify(mockLockVoteManager, never()).add(checked: equal(to: lockVote))
                            }
                        }
                        context("when has input for txHash") {
                            beforeEach {
                                stub(mockLockVoteManager) { mock in
                                    when(mock.add(checked: equal(to: lockVote))).thenDoNothing()
                                }
                            }
                            context("when input vote count equal or more needed") {
                                it("stops processing with equal") {
                                    let input = InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 2, blockHeight: nil)
                                    stub(mockInstantTransactionManager) { mock in
                                        when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))).thenReturn([input])
                                    }
                                    handler.handle(lockVote: lockVote)

                                    //check stops
                                    verify(mockLockVoteManager, never()).validate(lockVote: any())
                                }
                                it("stops processing with more") {
                                    let input = InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 5, blockHeight: nil)
                                    stub(mockInstantTransactionManager) { mock in
                                        when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))).thenReturn([input])
                                    }
                                    handler.handle(lockVote: lockVote)

                                    //check stops
                                    verify(mockLockVoteManager, never()).validate(lockVote: any())
                                }
                            }
                            context("when input has right parameters") {
                                beforeEach {
                                    stub(mockInstantTransactionManager) { mock in
                                        when(mock.instantTransactionInputs(for: equal(to: txHash), instantTransaction: equal(to: nil))).thenReturn(instantInputs)
                                    }
                                }
                                context("when validation catch error") {
                                    beforeEach {
                                        stub(mockLockVoteManager) { mock in
                                            when(mock.validate(lockVote: equal(to: lockVote))).thenThrow(DashKitErrors.LockVoteValidation.signatureNotValid)
                                        }
                                    }
                                    it("stops processing") {
                                        handler.handle(lockVote: lockVote)

                                        verify(mockLockVoteManager).validate(lockVote: equal(to: lockVote))
                                        //check stops
                                        verify(mockInstantTransactionManager, never()).updateInput(for: any(), transactionInputs: any())
                                    }
                                }
                                context("when validation success") {
                                    beforeEach {
                                        stub(mockLockVoteManager) { mock in
                                            when(mock.validate(lockVote: equal(to: lockVote))).thenDoNothing()
                                        }
                                        stub(mockInstantTransactionManager) { mock in
                                            when(mock.updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))).thenDoNothing()
                                        }
                                    }
                                    context("when transaction is not instant") {
                                        it("updates inputs and stops processing") {
                                            stub(mockInstantTransactionManager) { mock in
                                                when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(false)
                                            }
                                            handler.handle(lockVote: lockVote)

                                            verify(mockLockVoteManager).validate(lockVote: equal(to: lockVote))
                                            verify(mockInstantTransactionManager).updateInput(for: equal(to: inputTxHash), transactionInputs: equal(to: instantInputs))
                                            // call before handling vote and after to check new status
                                            verify(mockInstantTransactionManager, times(2)).isTransactionInstant(txHash: equal(to: txHash))
                                            //check stops
                                            verify(mockInstantTransactionDelegate, never()).onUpdateInstant(transactionHash: equal(to: txHash))
                                        }
                                        context("when transaction become instant") {
                                            it("call delegate update instant") {
                                                stub(mockInstantTransactionManager) { mock in
                                                    when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(false).thenReturn(true)
                                                }
                                                stub(mockInstantTransactionDelegate) { mock in
                                                    when(mock.onUpdateInstant(transactionHash: equal(to: txHash))).thenDoNothing()
                                                }
                                                handler.handle(lockVote: lockVote)

                                                // call before handling vote and after to check new status
                                                verify(mockInstantTransactionManager, times(2)).isTransactionInstant(txHash: equal(to: txHash))
                                                //check stops
                                                verify(mockInstantTransactionDelegate).onUpdateInstant(transactionHash: equal(to: txHash))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
