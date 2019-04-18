//import Foundation
//import XCTest
//import Quick
//import Nimble
//import Cuckoo
//@testable import BitcoinCore
//
//class InstantSendTests: QuickSpec {
//
//    override func spec() {
//        let mockInstantTransactionManager = MockIInstantTransactionManager()
//        let mockNextHandler = MockIPeerTaskHandler()
//
//        var instantSend: InstantSend!
//
//        beforeEach {
//            stub(mockInstantTransactionManager) { mock in
//                when(mock.handle(transactions: any())).thenDoNothing()
//                when(mock.handle(lockVote: any())).thenDoNothing()
//            }
//            stub(mockNextHandler) { mock in
//                when(mock.handleCompletedTask(peer: any(), task: any())).thenDoNothing()
//            }
//            instantSend = InstantSend(instantTransactionManager: mockInstantTransactionManager)
//            instantSend.set(successor: mockNextHandler)
//        }
//
//        afterEach {
//            reset(mockInstantTransactionManager, mockNextHandler)
//            instantSend = nil
//        }
//
//        describe("#handleCompletedTask(peer:, task:)") {
//            let mockPeer = MockIPeer()
//
//            it("handles request transaction ix task") {
//                let task = RequestTransactionLockRequestsTask(hashes: [])
//                let transactions = [TestData.p2pkhTransaction]
//
//                task.transactions = transactions
//
//                instantSend.handleCompletedTask(peer: mockPeer, task: task)
//
//                verify(mockInstantTransactionManager).handle(transactions: equal(to: transactions))
//            }
//
//            it("handles request transaction lock votes task") {
//                let task = RequestTransactionLockVotesTask(hashes: [])
//                let transactionLockVotes = [DashTestData.transactionLockVote(txHash: Data(repeating: 0, count: 32)), DashTestData.transactionLockVote(txHash: Data(repeating: 1, count: 32))]
//                task.transactionLockVotes = transactionLockVotes
//
//                instantSend.handleCompletedTask(peer: mockPeer, task: task)
//
//                verify(mockInstantTransactionManager).handle(lockVote: equal(to: transactionLockVotes[0]))
//                verify(mockInstantTransactionManager).handle(lockVote: equal(to: transactionLockVotes[1]))
//            }
//
//            it("not handles any dash custom tasks") {
//                let task = PeerTask()
//                instantSend.handleCompletedTask(peer: mockPeer, task: task)
//
//                verify(mockNextHandler).handleCompletedTask(peer: equal(to: mockPeer, equalWhen: { $0 === $1 }), task: equal(to: task))
//            }
//
//
//        }
//    }
//
//}
