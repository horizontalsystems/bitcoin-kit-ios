//import XCTest
//import Cuckoo
//import RxSwift
//import Alamofire
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class IPeerTests: XCTestCase {
//
//    internal var mockNetwork: MockINetwork!
//    internal var mockConnection: MockIPeerConnection!
//    internal var mockConnectionTimeoutManager: MockIConnectionTimeoutManager!
//    internal var mockPeerGroup: MockPeerDelegate!
//    internal var mockPeerTask: MockPeerTask!
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
//        mockPeerTask = MockPeerTask()
//
//        stub(mockNetwork) { mock in
//            when(mock.protocolVersion.get).thenReturn(70015)
//        }
//        stub(mockPeerTask) { mock in
//            when(mock.requester.set(any())).thenDoNothing()
//            when(mock.delegate.set(any())).thenDoNothing()
//            when(mock.start()).thenDoNothing()
//            when(mock.handle(blockHeaders: any())).thenReturn(false)
//            when(mock.handle(merkleBlock: any())).thenReturn(false)
//            when(mock.handle(transaction: any())).thenReturn(false)
//            when(mock.handle(getDataInventoryItem: any())).thenReturn(false)
//            when(mock.handle(items: any())).thenReturn(false)
//            when(mock.isRequestingInventory(hash: any())).thenReturn(false)
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
//        mockPeerTask = nil
//
//        peer = nil
//
//        super.tearDown()
//    }
//
//    func testConnect() {
//        peer.connect()
//        verify(mockConnection).connect()
//    }
//
//    func testDisconnect() {
//        let error = MerkleBlockValidator.ValidationError.duplicatedLeftOrRightBranches
//        peer.disconnect(error: error)
//        verify(mockConnection).disconnect(error: equal(to: error, equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testAdd() {
//        peer.add(task: mockPeerTask)
//
//        verify(mockPeerTask).delegate.set(equal(to: (peer as IPeerTaskDelegate), equalWhen: ===))
//        verify(mockPeerTask).requester.set(equal(to: (peer as IPeerTaskRequester), equalWhen: ===))
//        verify(mockPeerTask).start()
//        verifyNoMoreInteractions(mockPeerTask)
//    }
//
//    func testIsRequestingInventory() {
//        let invHash = Data(from: 1000)
//
//        XCTAssertEqual(peer.isRequestingInventory(hash: invHash), false)
//
//        peer.add(task: mockPeerTask)
//        stub(mockPeerTask) { mock in
//            when(mock.isRequestingInventory(hash: any())).thenReturn(false)
//        }
//
//        XCTAssertEqual(peer.isRequestingInventory(hash: invHash), false)
//        verify(mockPeerTask).isRequestingInventory(hash: equal(to: invHash))
//
//        stub(mockPeerTask) { mock in
//            when(mock.isRequestingInventory(hash: any())).thenReturn(true)
//        }
//
//        XCTAssertEqual(peer.isRequestingInventory(hash: invHash), true)
//    }
//
//    func testFilterLoad() {
//        let bloomFilter = BloomFilter(elements: [Data(from: 100000)])
//        let message = FilterLoadMessage(bloomFilter: bloomFilter)
//        peer.filterLoad(bloomFilter: bloomFilter)
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { ($0 as! FilterLoadMessage).bloomFilter.filter == ($1 as! FilterLoadMessage).bloomFilter.filter }))
//    }
//
//    func testSendMempoolMessage() {
//        let message = MemPoolMessage()
//        peer.sendMempoolMessage()
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testSendMempoolMessage_SecondTime() {
//        peer.sendMempoolMessage()
//        reset(mockConnection)
//        stub(mockConnection) { mock in
//            when(mock).send(message: any()).thenDoNothing()
//        }
//
//        peer.sendMempoolMessage()
//        verifyNoMoreInteractions(mockConnection)
//    }
//
//    func testEqualTo() {
//        let mockConnection2 = MockIPeerConnection()
//        stub(mockConnection2) { mock in
//            when(mock.delegate.set(any())).thenDoNothing()
//            when(mock.host.get).thenReturn("other_host")
//        }
//        let otherPeer = Peer(host: "", network: mockNetwork, connection: mockConnection2, connectionTimeoutManager: MockIConnectionTimeoutManager())
//
//        XCTAssertEqual(peer.equalTo(peer), true)
//        XCTAssertEqual(peer.equalTo(otherPeer), false)
//    }
//
//}
