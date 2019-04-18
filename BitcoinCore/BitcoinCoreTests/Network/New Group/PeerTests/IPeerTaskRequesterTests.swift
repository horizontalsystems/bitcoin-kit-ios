//import XCTest
//import Cuckoo
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class IPeerTaskRequesterTests: XCTestCase {
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
//    func testGetBlocks() {
//        let hash = Data(from: 100000)
//        let message = GetBlocksMessage(protocolVersion: 70015, headerHashes: [hash])
//
//        peer.getBlocks(hashes: [hash])
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { ($0 as! GetBlocksMessage).serialized() == ($1 as! GetBlocksMessage).serialized() }))
//    }
//
//    func testGetData() {
//        let item = InventoryItem(type: 0, hash: Data(from: 10000))
//        let message = GetDataMessage(inventoryItems: [item])
//
//        peer.getData(items: [item])
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { ($0 as! GetDataMessage).serialized() == ($1 as! GetDataMessage).serialized() }))
//    }
//
//    func testSendTransactionInventory() {
//        let hash = Data(from: 10000)
//        let message = InventoryMessage(inventoryItems: [InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: hash)])
//
//        peer.sendTransactionInventory(hash: hash)
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { ($0 as! InventoryMessage).serialized() == ($1 as! InventoryMessage).serialized() }))
//    }
//
//    func testSendTransaction() {
//        let transaction = TestData.p2pkTransaction
//        let message = TransactionMessage(transaction: transaction)
//
//        peer.send(transaction: transaction)
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { ($0 as! TransactionMessage).serialized() == ($1 as! TransactionMessage).serialized() }))
//    }
//
//    func testPing() {
//        let nonce = UInt64(1000)
//        let message = PingMessage(nonce: nonce)
//
//        peer.ping(nonce: nonce)
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { ($0 as! PingMessage).serialized() == ($1 as! PingMessage).serialized() }))
//    }
//
//}
