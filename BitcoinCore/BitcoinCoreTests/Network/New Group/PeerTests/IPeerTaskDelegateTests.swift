//import XCTest
//import Cuckoo
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class IPeerTaskDelegateTests: XCTestCase {
//
//    internal var mockNetwork: MockINetwork!
//    internal var mockConnection: MockIPeerConnection!
//    internal var mockConnectionTimeoutManager: MockIConnectionTimeoutManager!
//    internal var mockPeerGroup: MockPeerDelegate!
//
//    internal var peer: Peer!
//
//    override func setUp() {
//        super.setUp()
//
//        mockNetwork = MockINetwork()
//        mockConnection = MockIPeerConnection()
//        mockConnectionTimeoutManager = MockIConnectionTimeoutManager()
//        mockPeerGroup = MockPeerDelegate()
//
//        stub(mockNetwork) { mock in
//            when(mock.protocolVersion.get).thenReturn(70015)
//        }
//        stub(mockConnection) { mock in
//            when(mock.delegate.set(any())).thenDoNothing()
//            when(mock.host.get).thenReturn("")
//            when(mock.port.get).thenReturn(0)
//            when(mock.logName.get).thenReturn("")
//            when(mock).connect().thenDoNothing()
//            when(mock).disconnect(error: any()).thenDoNothing()
//            when(mock).send(message: any()).thenDoNothing()
//        }
//        stub(mockPeerGroup) { mock in
//            when(mock.peer(any(), didCompleteTask: any())).thenDoNothing()
//            when(mock.peerReady(any())).thenDoNothing()
//            when(mock.handle(any(), merkleBlock: any())).thenDoNothing()
//        }
//        stub(mockConnectionTimeoutManager) { mock in
//            when(mock.reset()).thenDoNothing()
//            when(mock.timePeriodPassed(peer: any())).thenDoNothing()
//        }
//
//        peer = Peer(host: "", network: mockNetwork, connection: mockConnection, connectionTimeoutManager: mockConnectionTimeoutManager, queue: DispatchQueue.main)
//        peer.delegate = mockPeerGroup
//    }
//
//    override func tearDown() {
//        mockNetwork = nil
//        mockConnection = nil
//        mockConnectionTimeoutManager = nil
//        mockPeerGroup = nil
//
//        peer = nil
//
//        super.tearDown()
//    }
//
//    func testHandleCompletedTask() {
//        let task = newTask()
//        let task2 = newTask()
//
//        peer.add(task: task)
//        peer.add(task: task2)
//        peer.handle(completedTask: task)
//
//        verify(mockPeerGroup).peer(equal(to: peer, equalWhen: { $0 === $1 }), didCompleteTask: equal(to: task, equalWhen: { $0 === $1 }))
//        verify(task2).resetTimer()
//        verify(mockPeerGroup, never()).peer(equal(to: peer, equalWhen: { $0 === $1 }), didCompleteTask: equal(to: task2, equalWhen: { $0 === $1 }))
//        verify(mockPeerGroup, never()).peerReady(any())
//    }
//
//    func testHandleCompletedTask_AllTasksFinished() {
//        let task = newTask()
//
//        peer.add(task: task)
//        peer.handle(completedTask: task)
//
//        verify(mockPeerGroup).peer(equal(to: peer, equalWhen: { $0 === $1 }), didCompleteTask: equal(to: task, equalWhen: { $0 === $1 }))
//        verify(mockPeerGroup).peerReady(equal(to: peer, equalWhen: { $0 === $1 }))
//    }
//
//    func testHandleCompletedTask_TaskNotFound() {
//        let task = newTask()
//
//        peer.handle(completedTask: task)
//
//        verify(mockPeerGroup, never()).peer(any(), didCompleteTask: any())
//        verify(mockPeerGroup).peerReady(equal(to: peer, equalWhen: { $0 === $1 }))
//    }
//
//    func testHandleFailedTask() {
//        let task = newTask()
//        let error = PeerTask.TimeoutError()
//
//        peer.handle(failedTask: task, error: error)
//
//        verifyNoMoreInteractions(mockPeerGroup)
//        verify(mockConnection).disconnect(error: equal(to: error, equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testHandleMerkleBlock() {
//        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header, transactionHashes: [], transactions: [])
//
//        peer.handle(merkleBlock: merkleBlock)
//
//        verify(mockPeerGroup).handle(equal(to: peer, equalWhen: { $0 === $1 }), merkleBlock: equal(to: merkleBlock, equalWhen: { $0.headerHash == $1.headerHash }))
//    }
//
//
//    private func newTask() -> MockPeerTask {
//        let mockTask = MockPeerTask()
//
//        stub(mockTask) { mock in
//            when(mock).delegate.set(any()).thenDoNothing()
//            when(mock).requester.set(any()).thenDoNothing()
//            when(mock).start().thenDoNothing()
//            when(mock).resetTimer().thenDoNothing()
//            when(mock).checkTimeout().thenDoNothing()
//        }
//
//        return mockTask
//    }
//
//}
