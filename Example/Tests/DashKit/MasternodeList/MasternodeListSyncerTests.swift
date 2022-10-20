//import Foundation
//import XCTest
//import Quick
//import Nimble
//import Cuckoo
//@testable import BitcoinCore
//
//class MasternodeListSyncerTests: QuickSpec {
//
//    override func spec() {
//        let mockPeerGroup = MockIPeerGroup()
//        let mockPeerTaskFactory = MockIPeerTaskFactory()
//        let mockMasternodeListManager = MockIMasternodeListManager()
//
//
//        var syncer: MasternodeListSyncer!
//
//        let baseBlockHash = Data(hex: "000000")!
//        let blockHash = Data(hex: "001122")!
//
//        beforeEach {
//            stub(mockPeerGroup) { mock in
//                when(mock.addTask(peerTask: any())).thenDoNothing()
//            }
//            stub(mockMasternodeListManager) { mock in
//                when(mock.updateList(masternodeListDiffMessage: any())).thenDoNothing()
//            }
//
//            syncer = MasternodeListSyncer(peerGroup: mockPeerGroup, peerTaskFactory: mockPeerTaskFactory, masternodeListManager: mockMasternodeListManager)
//        }
//
//        afterEach {
//            reset(mockPeerGroup, mockPeerTaskFactory, mockMasternodeListManager)
//
//            syncer = nil
//        }
//
//        describe("#sync") {
//            let task = MockPeerTask()
//
//            beforeEach {
//                stub(mockMasternodeListManager) { mock in
//                    when(mock.baseBlockHash.get).thenReturn(baseBlockHash)
//                }
//                stub(mockPeerTaskFactory) { mock in
//                    when(mock.createRequestMasternodeListDiffTask(baseBlockHash: equal(to: baseBlockHash), blockHash: equal(to: blockHash))).thenReturn(task)
//                }
//            }
//
//            it("adds get masternode diff task") {
//                syncer.sync(blockHash: blockHash)
//
//                verify(mockPeerGroup).addTask(peerTask: equal(to: task))
//            }
//        }
//
//        describe("#handleCompletedTask") {
//            let mockPeer = MockIPeer()
//            let peerTask = RequestMasternodeListDiffTask(baseBlockHash: baseBlockHash, blockHash: blockHash)
//
//            it("handle get masternode diff task") {
//                peerTask.masternodeListDiffMessage = self.taskMessage(baseBlockHash: baseBlockHash, blockHash: blockHash)
//                syncer.handleCompletedTask(peer: mockPeer, task: peerTask)
//
//                verify(mockMasternodeListManager).updateList(masternodeListDiffMessage: equal(to: peerTask.masternodeListDiffMessage!))
//            }
//
//            it("handle get task but got error from manager") {
//                enum TestError: Error { case test }
//                let error: Error = TestError.test
//
//                stub(mockPeer) { mock in
//                    when(mock.disconnect(error: equal(to: error, equalWhen: { type(of: $0) == type(of: $1) }))).thenDoNothing()
//                }
//                stub(mockMasternodeListManager) { mock in
//                    when(mock.updateList(masternodeListDiffMessage: any())).thenThrow(error)
//                }
//                stub(mockPeerTaskFactory) { mock in
//                    when(mock.createRequestMasternodeListDiffTask(baseBlockHash: equal(to: baseBlockHash), blockHash: equal(to: blockHash))).thenReturn(peerTask)
//                }
//
//                syncer.handleCompletedTask(peer: mockPeer, task: peerTask)
//
//                verify(mockPeer).disconnect(error: equal(to: error, equalWhen: { type(of: $0) == type(of: $1) }))
//                verify(mockPeerGroup).addTask(peerTask: equal(to: peerTask))
//            }
//
//            it("handle task without message") {
//                let mockSuccessor = MockIPeerTaskHandler()
//                let peerTask = MockPeerTask()
//
//                stub(mockSuccessor) { mock in
//                    when(mock.handleCompletedTask(peer: any(), task: any())).thenDoNothing()
//                }
//
//                syncer.set(successor: mockSuccessor)
//                syncer.handleCompletedTask(peer: mockPeer, task: peerTask)
//
//                verify(mockSuccessor).handleCompletedTask(peer: equal(to: mockPeer, equalWhen: { $0 === $1 }), task: equal(to: peerTask))
//            }
//        }
//    }
//
//    private func taskMessage(baseBlockHash: Data, blockHash: Data) -> MasternodeListDiffMessage {
//        let cbTx = CoinbaseTransaction(transaction: TestData.p2pkhTransaction, coinbaseTransactionSize: Data(bytes: [0]), version: 0, height: 0, merkleRootMNList: Data())
//
//        return MasternodeListDiffMessage(baseBlockHash: baseBlockHash, blockHash: blockHash,
//                totalTransactions: 0, merkleHashesCount: 0, merkleHashes: [],
//                merkleFlagsCount: 0, merkleFlags: Data(), cbTx: cbTx, deletedMNsCount: 0,
//                deletedMNs: [], mnListCount: 0, mnList: [])
//    }
//
//}
