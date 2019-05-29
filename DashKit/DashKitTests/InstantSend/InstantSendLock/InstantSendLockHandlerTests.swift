import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore
@testable import DashKit

class InstantSendLockHandlerTests: QuickSpec {

    override func spec() {
        let mockInstantTransactionDelegate = MockIInstantTransactionDelegate()
        let mockInstantSendLockManager = MockIInstantSendLockManager()
        let mockInstantTransactionManager = MockIInstantTransactionManager()

        let handler = InstantSendLockHandler(instantTransactionManager: mockInstantTransactionManager, instantSendLockManager: mockInstantSendLockManager)
        handler.delegate = mockInstantTransactionDelegate

        afterEach {
            reset(mockInstantTransactionManager, mockInstantSendLockManager, mockInstantTransactionDelegate)
        }

        let txHash = DashTestData.transaction.header.dataHash
        let hash = Data(hex: "1234")!

        let isLock = ISLockMessage(inputs: [], txHash: txHash, sign: Data(), hash: hash)

        describe("#handle(transactionHash: Data)") {
            context("when hasn't related lock") {
                it("stops processing") {
                    stub(mockInstantSendLockManager) { mock in
                        when(mock.takeRelayedLock(for: equal(to: txHash))).thenReturn(nil)
                    }
                    handler.handle(transactionHash: txHash)
                    verify(mockInstantSendLockManager).takeRelayedLock(for: equal(to: txHash))
                    // check stops
                    verify(mockInstantSendLockManager, never()).validate(isLock: any())
                }
            }
            context("when has related lock") {
                beforeEach {
                    stub(mockInstantSendLockManager) { mock in
                        when(mock.takeRelayedLock(for: equal(to: txHash))).thenReturn(isLock)
                    }
                }
                context("when wrong validation") {
                    it("stops processing") {
                        stub(mockInstantSendLockManager) { mock in
                            when(mock.validate(isLock: equal(to: isLock))).thenThrow(DashKitErrors.InstantSendLockValidation.signatureNotValid)
                        }
                        handler.handle(transactionHash: txHash)
                        verify(mockInstantSendLockManager).takeRelayedLock(for: equal(to: txHash))
                        verify(mockInstantSendLockManager).validate(isLock: equal(to: isLock))
                        // check stops
                        verify(mockInstantTransactionManager, never()).makeInstant(txHash: any())
                    }
                }
                context("when successful validated") {
                    it("make instant and call delegate update") {
                        stub(mockInstantSendLockManager) { mock in
                            when(mock.validate(isLock: equal(to: isLock))).thenDoNothing()
                        }
                        stub(mockInstantTransactionManager) { mock in
                            when(mock.makeInstant(txHash: equal(to: txHash))).thenDoNothing()
                        }
                        stub(mockInstantTransactionDelegate) { mock in
                            when(mock.onUpdateInstant(transactionHash: equal(to: txHash))).thenDoNothing()
                        }
                        handler.handle(transactionHash: txHash)
                        verify(mockInstantTransactionManager).makeInstant(txHash: equal(to: txHash))
                        verify(mockInstantTransactionDelegate).onUpdateInstant(transactionHash: equal(to: txHash))
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
                    handler.handle(isLock: isLock)
                    verify(mockInstantTransactionManager).isTransactionInstant(txHash: equal(to: txHash))
                    // check stops
                    verify(mockInstantTransactionManager, never()).isTransactionExists(txHash: any())
                }
            }
            context("when transaction not instant") {
                beforeEach {
                    stub(mockInstantTransactionManager) { mock in
                        when(mock.isTransactionInstant(txHash: equal(to: txHash))).thenReturn(false)
                    }
                }
                context("when transaction not exist") {
                    it("add to relayed and stops processing") {
                        stub(mockInstantTransactionManager) { mock in
                            when(mock.isTransactionExists(txHash: equal(to: txHash))).thenReturn(false)
                        }
                        stub(mockInstantSendLockManager) { mock in
                            when(mock.add(relayed: equal(to: isLock))).thenDoNothing()
                        }
                        handler.handle(isLock: isLock)
                        verify(mockInstantTransactionManager).isTransactionExists(txHash: equal(to: txHash))
                        verify(mockInstantSendLockManager).add(relayed: equal(to: isLock))
                        // check stops
                        verify(mockInstantSendLockManager, never()).validate(isLock: any())
                    }
                }
                context("when transaction exist") {
                    beforeEach {
                        stub(mockInstantTransactionManager) { mock in
                            when(mock.isTransactionExists(txHash: equal(to: txHash))).thenReturn(true)
                        }
                    }
                    context("when wrong validation") {
                        it("stops processing") {
                            stub(mockInstantSendLockManager) { mock in
                                when(mock.validate(isLock: equal(to: isLock))).thenThrow(DashKitErrors.InstantSendLockValidation.signatureNotValid)
                            }
                            handler.handle(isLock: isLock)
                            verify(mockInstantTransactionManager).isTransactionExists(txHash: equal(to: txHash))
                            verify(mockInstantSendLockManager).validate(isLock: equal(to: isLock))
                            // check stops
                            verify(mockInstantTransactionManager, never()).makeInstant(txHash: any())
                        }
                    }
                    context("when successful validated") {
                        it("make instant and call delegate update") {
                            stub(mockInstantSendLockManager) { mock in
                                when(mock.validate(isLock: equal(to: isLock))).thenDoNothing()
                            }
                            stub(mockInstantTransactionManager) { mock in
                                when(mock.makeInstant(txHash: equal(to: txHash))).thenDoNothing()
                            }
                            stub(mockInstantTransactionDelegate) { mock in
                                when(mock.onUpdateInstant(transactionHash: equal(to: txHash))).thenDoNothing()
                            }
                            handler.handle(isLock: isLock)
                            verify(mockInstantTransactionManager).makeInstant(txHash: equal(to: txHash))
                            verify(mockInstantTransactionDelegate).onUpdateInstant(transactionHash: equal(to: txHash))
                        }
                    }
                }

            }

        }
    }
}
