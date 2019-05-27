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
        let mockState = MockIInstantTransactionState()

        var manager: InstantTransactionManager!

        let transaction = DashTestData.transaction
        let txHash = transaction.header.dataHash
        let inputTxHash = Data(transaction.inputs[0].previousOutputTxHash)

        let instantInputs = [InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 0, blockHeight: nil)]
        let hashes = [Data(repeating: 1, count: 2), Data(repeating: 2, count: 2)]

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.add(instantTransactionInput: any())).thenDoNothing()
                when(mock.instantTransactionHashes()).thenReturn(hashes)
            }
            stub(mockState) { mock in
                when(mock.instantTransactionHashes.set(any())).thenDoNothing()
            }
            stub(mockInstantSendFactory) { mock in
                when(mock.instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 0, blockHeight: equal(to: nil))).thenReturn(instantInputs[0])
            }
            manager = InstantTransactionManager(storage: mockStorage, instantSendFactory: mockInstantSendFactory, instantTransactionState: mockState)
        }

        afterEach {
            reset(mockStorage, mockState, mockInstantSendFactory)
            manager = nil
        }
        describe("#init") {
            it("puts tx hashes to state from storage") {
                verify(mockStorage).instantTransactionHashes()
                verify(mockState).instantTransactionHashes.set(equal(to: hashes))
            }
        }
        describe("#instantTransactionInputs(for txHash: Data, instantTransaction: FullTransaction?)") {
            beforeEach {
                stub(mockStorage) { mock in
                    when(mock.instantTransactionHashes()).thenReturn([])
                }
            }
            it("returns inputs from storage") {
                stub(mockStorage) { mock in
                    when(mock.instantTransactionInputs(for: equal(to: txHash))).thenReturn(instantInputs)
                }
                let inputs = manager.instantTransactionInputs(for: txHash, instantTransaction: nil)

                expect(inputs).to(equal(instantInputs))
                verify(mockStorage).instantTransactionInputs(for: equal(to: txHash))
                verifyNoMoreInteractions(mockInstantSendFactory)
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
            }
        }
        describe("#updateInput(for inputTxHash: Data, transactionInputs: [InstantTransactionInput])") {
            it("stops work if can't find input for vote") {
                let lockVote = DashTestData.transactionLockVote(txHash: txHash, inputTxHash: Data(repeating: 9, count: 9))

                do {
                    try manager.updateInput(for: lockVote.outpoint.txHash, transactionInputs: instantInputs)
                } catch let error as DashKitErrors.LockVoteValidation {
                    expect(error).to(equal(DashKitErrors.LockVoteValidation.txInputNotFound))
                } catch {
                    XCTFail("Wrong Error!")
                }
            }
            describe("when found input") {
                let lockVote = DashTestData.transactionLockVote(txHash: txHash, inputTxHash: inputTxHash)
                let updatedInput = InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 1, blockHeight: nil)
                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.add(instantTransactionInput: equal(to: instantInputs[0]))).thenDoNothing()
                    }
                    stub(mockInstantSendFactory) { mock in
                        when(mock.instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 1, blockHeight: equal(to: nil))).thenReturn(updatedInput)
                    }
                }
                it("increases input and saves to storage") {
                    try! manager.updateInput(for: lockVote.outpoint.txHash, transactionInputs: instantInputs)
                    verify(mockInstantSendFactory).instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 1, blockHeight: equal(to: nil))
                    verify(mockStorage).add(instantTransactionInput: equal(to: instantInputs[0]))
                }
                it("stops work if not all inputs has expected voteCount") {
                    try! manager.updateInput(for: lockVote.outpoint.txHash, transactionInputs: instantInputs)
                    verify(mockState, never()).append(equal(to: txHash))
                    verify(mockStorage, never()).add(instantTransactionHash: equal(to: txHash))
                }
                describe("when all inputs has expected voteCount") {
                    let inputs = [InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 5, blockHeight: nil),
                                         InstantTransactionInput(txHash: txHash, inputTxHash: Data(repeating: 8, count: 2), timeCreated: 0, voteCount: 6, blockHeight: nil)
                    ]
                    let updatedInput = InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 6, blockHeight: nil)
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.add(instantTransactionHash: equal(to: txHash))).thenDoNothing()
                            when(mock.removeInstantTransactionInputs(for: equal(to: txHash))).thenDoNothing()
                        }
                        stub(mockInstantSendFactory) { mock in
                            when(mock.instantTransactionInput(txHash: equal(to: txHash), inputTxHash: equal(to: inputTxHash), voteCount: 6, blockHeight: equal(to: nil))).thenReturn(updatedInput)
                        }
                        stub(mockState) { mock in
                            when(mock.append(equal(to: txHash))).thenDoNothing()
                        }
                    }
                    it("appends txHash to state and storage, delete instantTransactionInputs") {
                        try! manager.updateInput(for: lockVote.outpoint.txHash, transactionInputs: inputs)
                        verify(mockState).append(equal(to: txHash))
                        verify(mockStorage).add(instantTransactionHash: equal(to: txHash))
                        verify(mockStorage).removeInstantTransactionInputs(for: equal(to: txHash))
                    }
                }
            }
        }
        describe("#isTransactionInstant(txHash: Data)") {
            beforeEach {
                stub(mockState) {mock in
                    when(mock.instantTransactionHashes.get).thenReturn([])
                }
            }
            it("returns false when can't find txHash") {
                let instant = manager.isTransactionInstant(txHash: txHash)

                expect(instant).to(equal(false))
                verify(mockState).instantTransactionHashes.get()
            }
            it("returns true when hashes contains txHash") {
                stub(mockState) { mock in
                    when(mock.instantTransactionHashes.get).thenReturn([txHash])
                }
                let instant = manager.isTransactionInstant(txHash: txHash)

                expect(instant).to(equal(true))
                verify(mockState).instantTransactionHashes.get()
            }
        }
        describe("#isTransactionExists(txHash: Data)") {
            let existTxHash = Data(hex: "0101")!
            let notExistTxHash = Data(hex: "0202")!
            beforeEach {
                stub(mockStorage) {mock in
                    when(mock.transactionExists(byHash: equal(to: existTxHash))).thenReturn(true)
                    when(mock.transactionExists(byHash: equal(to: notExistTxHash))).thenReturn(false)
                }
            }
            it("returns true if exist") {
                let exist = manager.isTransactionExists(txHash: existTxHash)

                expect(exist).to(equal(true))
                verify(mockStorage).transactionExists(byHash: equal(to: existTxHash))
            }
            it("returns false when not exist") {
                let exist = manager.isTransactionExists(txHash: notExistTxHash)

                expect(exist).to(equal(false))
                verify(mockStorage).transactionExists(byHash: equal(to: notExistTxHash))
            }
        }
        describe("#makeInstant(txHash: Data)") {
            let txHash = Data(hex: "0101")!
            beforeEach {
                stub(mockStorage) {mock in
                    when(mock.add(instantTransactionHash: equal(to: txHash))).thenDoNothing()
                }
                stub(mockState) {mock in
                    when(mock.append(equal(to: txHash))).thenDoNothing()
                }
            }
            it("add txHash") {
                manager.makeInstant(txHash: txHash)

                verify(mockState).append(equal(to: txHash))
                verify(mockStorage).add(instantTransactionHash: equal(to: txHash))
            }
        }
    }

}
