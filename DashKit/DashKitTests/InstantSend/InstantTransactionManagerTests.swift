//import Foundation
//import XCTest
//import Quick
//import Nimble
//import Cuckoo
//@testable import BitcoinCore
//
//class InstantTransactionManagerTests: QuickSpec {
//
//    override func spec() {
//        let mockStorage = MockIDashStorage()
//        let mockInstantSendFactory = MockIInstantSendFactory()
//        let mockTransactionSyncer = MockITransactionSyncer()
//
//        var manager: InstantTransactionManager!
//
//        let transaction = TestData.p2pkhTransaction
//        let inputTxHash = Data(Data(hex: transaction.inputs[0].previousOutputTxReversedHex)!.reversed())
//
//        beforeEach {
//            stub(mockStorage) { mock in
//                when(mock.add(instantTransactionInput: any())).thenDoNothing()
//                when(mock.instantTransactionInput(for: any())).thenReturn(InstantTransactionInput(txHash: Data(), inputTxHash: Data(), timeCreated: 0, voteCount: 0, blockHeight: nil))
//            }
//            stub(mockTransactionSyncer) { mock in
//                when(mock.handle(transactions: any())).thenDoNothing()
//            }
//            manager = InstantTransactionManager(storage: mockStorage, instantSendFactory: mockInstantSendFactory, transactionSyncer: mockTransactionSyncer)
//        }
//
//        afterEach {
//            reset(mockTransactionSyncer, mockStorage)
//            manager = nil
//        }
//
//        describe("#handle(transactions:)") {
//
//            it("ignores empty transaction list") {
//                manager.handle(transactions: [])
//
//                verifyNoMoreInteractions(mockTransactionSyncer)
//            }
//
//            it("creates successful instant transaction") {
//                let input = InstantTransactionInput(txHash: transaction.header.dataHash, inputTxHash: inputTxHash, timeCreated: Int(Date().timeIntervalSince1970), voteCount: 0, blockHeight: nil)
//                stub(mockInstantSendFactory) { mock in
//                    when(mock.instantTransactionInput(txHash: equal(to: transaction.dataHash), inputTxHash: equal(to: inputTxHash), voteCount: input.voteCount, blockHeight: isNil())).thenReturn(input)
//                }
//
//                manager.handle(transactions: [transaction])
//
//                verify(mockInstantSendFactory).instantTransactionInput(txHash: equal(to: input.txHash), inputTxHash: equal(to: inputTxHash), voteCount: input.voteCount, blockHeight: isNil())
//                verify(mockStorage).add(instantTransactionInput: equal(to: input))
//                verify(mockTransactionSyncer).handle(transactions: equal(to: [transaction]))
//            }
//        }
//
//        describe("#handle(lockVote:)") {
//
//            it("adds successful lockVote") {
//                let transactionLockMessage = DashTestData.transactionLockVote(txHash: transaction.header.dataHash, inputTxHash: inputTxHash)
//                let input = InstantTransactionInput(txHash: transaction.header.dataHash, inputTxHash: inputTxHash, timeCreated: 0, voteCount: 0, blockHeight: nil)
//
//                stub(mockStorage) { mock in
//                    when(mock.add(instantTransactionInput: any())).thenDoNothing()
//                    when(mock.instantTransactionInput(for: any())).thenReturn(input)
//                }
//
//                try! manager.handle(lockVote: transactionLockMessage)
//
//                verify(mockStorage).instantTransactionInput(for: equal(to: inputTxHash))
//
//                verify(mockStorage).add(instantTransactionInput: any())
//                verify(mockInstantSendFactory).instantTransactionInput(txHash: equal(to: input.txHash), inputTxHash: equal(to: inputTxHash), voteCount: input.voteCount, blockHeight: isNil())
//                verify(mockTransactionSyncer).handle(transactions: equal(to: [transaction]))
//            }
//        }
//    }
//
//}
