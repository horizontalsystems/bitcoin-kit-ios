import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import DashKit

class InstantTransactionManagerTests: QuickSpec {

    override func spec() {
        let mockStorage = MockIDashStorage()
        let mockInstantSendFactory = MockIInstantSendFactory()
        let mockTransactionValidator = MockITransactionLockVoteValidator()

        var manager: InstantTransactionManager!

        let transaction = DashTestData.transaction
        let txHash = transaction.header.dataHash
        let inputTxHash = Data(transaction.inputs[0].previousOutputTxHash)

        let instantInputs = [InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 0, blockHeight: nil)]

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.add(instantTransactionInput: any())).thenDoNothing()
            }
            stub(mockTransactionValidator) { mock in
                when(mock.validate(quorumModifierHash: any(), masternodeProTxHash: any())).thenDoNothing()
            }
            stub(mockInstantSendFactory) { mock in
                when(mock.instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 0, blockHeight: equal(to: nil))).thenReturn(instantInputs[0])
            }
            manager = InstantTransactionManager(storage: mockStorage, instantSendFactory: mockInstantSendFactory, transactionLockVoteValidator: mockTransactionValidator)
        }

        afterEach {
            reset(mockStorage, mockInstantSendFactory, mockTransactionValidator)
            manager = nil
        }

        describe("#instantTransactionInputs(for txHash: Data, instantTransaction: FullTransaction?)") {
            it("returns inputs from storage") {
                stub(mockStorage) { mock in
                    when(mock.instantTransactionInputs(for: equal(to: txHash))).thenReturn(instantInputs)
                }
                let inputs = manager.instantTransactionInputs(for: txHash, instantTransaction: nil)

                expect(inputs).to(equal(instantInputs))
                verify(mockStorage).instantTransactionInputs(for: equal(to: txHash))
                verifyNoMoreInteractions(mockInstantSendFactory)
                verifyNoMoreInteractions(mockTransactionValidator)
            }
            it("returns inputs from instant transaction") {
                stub(mockStorage) { mock in
                    when(mock.instantTransactionInputs(for: equal(to: txHash))).thenReturn([])
                }
                let inputs = manager.instantTransactionInputs(for: txHash, instantTransaction: transaction)

                expect(inputs).to(equal(instantInputs))
                verify(mockStorage).instantTransactionInputs(for: equal(to: txHash))
                verify(mockInstantSendFactory).instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 0, blockHeight: equal(to: nil))
                verify(mockStorage).add(instantTransactionInput: equal(to: instantInputs[0]))

                verifyNoMoreInteractions(mockTransactionValidator)
            }
            it("returns inputs from instant transaction") {
                stub(mockStorage) { mock in
                    when(mock.instantTransactionInputs(for: equal(to: txHash))).thenReturn([])
                    when(mock.inputs(transactionHash: any())).thenReturn(transaction.inputs)
                }
                let inputs = manager.instantTransactionInputs(for: txHash, instantTransaction: nil)

                expect(inputs).to(equal(instantInputs))
                verify(mockStorage).instantTransactionInputs(for: equal(to: txHash))
                verify(mockStorage).inputs(transactionHash: equal(to: txHash))
                verify(mockInstantSendFactory).instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 0, blockHeight: equal(to: nil))
                verify(mockStorage).add(instantTransactionInput: equal(to: instantInputs[0]))

                verifyNoMoreInteractions(mockTransactionValidator)
            }
        }

        describe("#increaseVoteCount(for input: InstantTransactionInput)") {
            it("ignores increase if can't get input from storage") {
                stub(mockStorage) { mock in
                    when(mock.instantTransactionInput(for: equal(to: inputTxHash))).thenReturn(nil)
                }

                manager.increaseVoteCount(for: instantInputs[0].inputTxHash)

                verify(mockInstantSendFactory, never()).instantTransactionInput(txHash: any(), inputTxHash: any(), voteCount: any(), blockHeight: any())
                verify(mockStorage, never()).add(instantTransactionInput: any())
            }
            it("adds 1 for input and save to storage") {
                let expectedInput = InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 1, blockHeight: nil)
                stub(mockStorage) { mock in
                    when(mock.instantTransactionInput(for: equal(to: inputTxHash))).thenReturn(instantInputs[0])
                }
                stub(mockInstantSendFactory) { mock in
                    when(mock.instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 1, blockHeight: equal(to: nil))).thenReturn(expectedInput)
                }

                manager.increaseVoteCount(for: instantInputs[0].inputTxHash)

                verify(mockInstantSendFactory).instantTransactionInput(txHash: equal(to: expectedInput.txHash), inputTxHash: equal(to: expectedInput.inputTxHash), voteCount: 1, blockHeight: equal(to: nil))
                verify(mockStorage).add(instantTransactionInput: equal(to: expectedInput))
            }
        }
        describe("#isTransactionInstant(txHash: Data)") {
            it("returns false when can't find inputs") {
                stub(mockStorage) { mock in
                    when(mock.instantTransactionInputs(for: equal(to: txHash))).thenReturn([])
                }
                let instant = manager.isTransactionInstant(txHash: txHash)

                expect(instant).to(equal(false))
                verify(mockStorage).instantTransactionInputs(for: equal(to: txHash))
            }
            it("returns false when some inputs has less than 6 votes") {
                let instantInputs = [
                    InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 6, blockHeight: nil),
                    InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 5, blockHeight: nil),
                    InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 6, blockHeight: nil),
                ]

                stub(mockStorage) { mock in
                    when(mock.instantTransactionInputs(for: equal(to: txHash))).thenReturn(instantInputs)
                }
                let instant = manager.isTransactionInstant(txHash: txHash)

                expect(instant).to(equal(false))
                verify(mockStorage).instantTransactionInputs(for: equal(to: txHash))
            }
            it("returns true when all inputs has more 5 votes") {
                let instantInputs = [
                    InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 6, blockHeight: nil),
                    InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 7, blockHeight: nil),
                    InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 6, blockHeight: nil),
                ]

                stub(mockStorage) { mock in
                    when(mock.instantTransactionInputs(for: equal(to: txHash))).thenReturn(instantInputs)
                }
                let instant = manager.isTransactionInstant(txHash: txHash)

                expect(instant).to(equal(true))
                verify(mockStorage).instantTransactionInputs(for: equal(to: txHash))
            }
        }
    }

}
