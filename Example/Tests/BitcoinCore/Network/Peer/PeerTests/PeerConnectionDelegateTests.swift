//import XCTest
//import Cuckoo
//import RxSwift
//import Alamofire
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class PeerConnectionDelegateTests: XCTestCase {
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
//        resetMockConnection()
//        stub(mockNetwork) { mock in
//            when(mock.protocolVersion.get).thenReturn(70015)
//        }
//        stub(mockPeerGroup) { mock in
//            when(mock.peerDidConnect(any())).thenDoNothing()
//            when(mock.peerDidDisconnect(any(), withError: any())).thenDoNothing()
//            when(mock.peer(any(), didReceiveAddresses: any())).thenDoNothing()
//            when(mock.peer(any(), didReceiveInventoryItems: any())).thenDoNothing()
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
//    func testConnectionAlive() {
//        peer.connectionAlive()
//        verify(mockConnectionTimeoutManager).reset()
//    }
//
//    func testConnectionTimePeriodPassed() {
//        let mockTask = MockPeerTask()
//        stub(mockTask) { mock in
//            when(mock).delegate.set(any()).thenDoNothing()
//            when(mock).requester.set(any()).thenDoNothing()
//            when(mock).start().thenDoNothing()
//            when(mock).resetTimer().thenDoNothing()
//            when(mock).checkTimeout().thenDoNothing()
//        }
//
//        peer.add(task: mockTask)
//        peer.connectionTimePeriodPassed()
//        waitForMainQueue()
//        verify(mockConnectionTimeoutManager).timePeriodPassed(peer: equal(to: peer, equalWhen: { $0.host == $1.host }))
//        verify(mockTask).checkTimeout()
//    }
//
//    func testConnectionReadyForWrite() {
//        let localBestBlockHeight = Int32(100)
//        let message = VersionMessage(
//                version: 0, services: 0, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: localBestBlockHeight, relay: false
//        )
//
//        peer.localBestBlockHeight = localBestBlockHeight
//        peer.connectionReadyForWrite()
//
//        verify(mockConnection).send(message: equal(to: message, equalWhen: { ($0 as! VersionMessage).startHeight == ($1 as! VersionMessage).startHeight }))
//    }
//
//    func testConnectionReadyForWrite_SecondTime() {
//        peer.connectionReadyForWrite()
//        reset(mockConnection)
//        stub(mockConnection) { mock in
//            when(mock.send(message: any())).thenDoNothing()
//        }
//
//        peer.connectionReadyForWrite()
//
//        verifyNoMoreInteractions(mockConnection)
//    }
//
//    func testConnectionDidDisconnect() {
//        peer.connectionDidDisconnect(withError: nil)
//
//        XCTAssertEqual(peer.connected, false)
//        verify(mockPeerGroup).peerDidDisconnect(equal(to: peer, equalWhen: { $0 === $1 }), withError: isNil())
//    }
//
//    func testConnectionDidReceiveMessage_VersionMessage() {
//        let startHeight = Int32(100)
//        let message = VersionMessage(
//                version: 70014, services: 1, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: startHeight, relay: false
//        )
//
//        peer.connected = true
//        peer.localBestBlockHeight = 10
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.announcedLastBlockHeight, startHeight)
//        verify(mockConnection).send(message: equal(to: VerackMessage(), equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testConnectionDidReceiveMessage_VersionMessage_WhenNotConnected() {
//        let startHeight = Int32(100)
//        let message = VersionMessage(
//                version: 70014, services: 1, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: startHeight, relay: false
//        )
//
//        peer.connected = false
//        peer.localBestBlockHeight = 10
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.announcedLastBlockHeight, startHeight)
//        verify(mockConnection).send(message: equal(to: VerackMessage(), equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testConnectionDidReceiveMessage_VersionMessage_HeightLessThanOne() {
//        let startHeight = Int32(0)
//        let message = VersionMessage(
//                version: 70014, services: 1, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: startHeight, relay: false
//        )
//
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.announcedLastBlockHeight, 0)
//        verify(mockConnection, never()).send(message: any())
//        verify(mockConnection).disconnect(error: equal(to: Peer.PeerError.peerBestBlockIsLessThanOne, equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testConnectionDidReceiveMessage_VersionMessage_HeightIsLessThanLocalBestHeight() {
//        let startHeight = Int32(9)
//        let message = VersionMessage(
//                version: 70014, services: 1, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: startHeight, relay: false
//        )
//
//        peer.localBestBlockHeight = 10
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.announcedLastBlockHeight, 0)
//        verify(mockConnection, never()).send(message: any())
//        verify(mockConnection).disconnect(error: equal(to: Peer.PeerError.peerHasExpiredBlockChain(localHeight: 10, peerHeight: 9), equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testConnectionDidReceiveMessage_VersionMessage_PeerNotFullNode() {
//        let startHeight = Int32(100)
//        let message = VersionMessage(
//                version: 70014, services: 0, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: startHeight, relay: false
//        )
//
//        peer.localBestBlockHeight = 10
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.announcedLastBlockHeight, 0)
//        verify(mockConnection, never()).send(message: any())
//        verify(mockConnection).disconnect(error: equal(to: Peer.PeerError.peerNotFullNode, equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testConnectionDidReceiveMessage_VersionMessage_DoesNotSupportBloomFilter() {
//        let startHeight = Int32(100)
//        let message = VersionMessage(
//                version: 60000, services: 1, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: startHeight, relay: false
//        )
//
//        peer.localBestBlockHeight = 10
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.announcedLastBlockHeight, 0)
//        verify(mockConnection, never()).send(message: any())
//        verify(mockConnection).disconnect(error: equal(to: Peer.PeerError.peerDoesNotSupportBloomFilter, equalWhen: { type(of: $0) == type(of: $1) }))
//    }
//
//    func testConnectionDidReceiveMessage_VersionMessage_Repeats() {
//        let startHeight = Int32(100)
//        let message = VersionMessage(
//                version: 70014, services: 1, timestamp: 0,
//                yourAddress: NetworkAddress(services: 0, address: "", port: 0), myAddress: NetworkAddress(services: 0, address: "", port: 0),
//                nonce: 0, userAgent: "0000", startHeight: startHeight, relay: false
//        )
//
//        peer.localBestBlockHeight = 10
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        resetMockConnection()
//
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.announcedLastBlockHeight, startHeight)
//        verify(mockConnection, never()).send(message: any())
//        verify(mockConnection, never()).disconnect(error: any())
//    }
//
//    func testConnectionDidReceiveMessage_VerackMessage() {
//        let message = VerackMessage()
//
//        peer.connected = true
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.connected, true)
//        verify(mockPeerGroup).peerDidConnect(equal(to: peer, equalWhen: { $0 === $1 }))
//    }
//
//    func testConnectionDidReceiveMessage_VerackMessage_WhenNotConnected() {
//        let message = VerackMessage()
//
//        peer.connected = false
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        XCTAssertEqual(peer.connected, true)
//        verify(mockPeerGroup).peerDidConnect(equal(to: peer, equalWhen: { $0 === $1 }))
//    }
//
//    func testConnectionDidReceiveMessage_AddressMessage() {
//        let networkAddress = NetworkAddress(services: 0, address: "", port: 0)
//        let message = AddressMessage(addresses: [networkAddress])
//
//        peer.connected = true
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        let networkAddressesCompareFunction: ([NetworkAddress], [NetworkAddress]) -> Bool = listCompareFunction(compareItemFunction: { $0.address == $1.address })
//        verify(mockPeerGroup).peer(equal(to: peer, equalWhen: { $0 === $1 }), didReceiveAddresses: equal(to: [networkAddress], equalWhen: networkAddressesCompareFunction))
//    }
//
//    func testConnectionDidReceiveMessage_AddressMessage_WhenNotConnected() {
//        let networkAddress = NetworkAddress(services: 0, address: "", port: 0)
//        let message = AddressMessage(addresses: [networkAddress])
//
//        peer.connected = false
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockPeerGroup, never()).peer(any(), didReceiveAddresses: any())
//    }
//
//    func testConnectionDidReceiveMessage_InventoryMessage() {
//        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 100000))
//        let message = InventoryMessage(inventoryItems: [inv])
//
//        peer.connected = true
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        let networkAddressesCompareFunction: ([InventoryItem], [InventoryItem]) -> Bool = listCompareFunction(compareItemFunction: { $0.hash == $1.hash })
//        verify(mockPeerGroup).peer(equal(to: peer, equalWhen: { $0 === $1 }), didReceiveInventoryItems: equal(to: [inv], equalWhen: networkAddressesCompareFunction))
//    }
//
//    func testConnectionDidReceiveMessage_InventoryMessage_WhenNotConnected() {
//        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 100000))
//        let message = InventoryMessage(inventoryItems: [inv])
//
//        peer.connected = false
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockPeerGroup, never()).peer(any(), didReceiveInventoryItems: any())
//    }
//
//    func testConnectionDidReceiveMessage_InventoryMessage_TaskHasRequestedInventory() {
//        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 100000))
//        let message = InventoryMessage(inventoryItems: [inv])
//
//        peer.connected = true
//        peer.add(task: newTask(extraMocks: { when($0).handle(items: any()).thenReturn(true) }))
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockPeerGroup, never()).peer(any(), didReceiveInventoryItems: any())
//    }
//
//    func testConnectionDidReceiveMessage_GetDataMessage() {
//        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 100000))
//        let message = GetDataMessage(inventoryItems: [inv])
//        let task = newTask(extraMocks: { when($0).handle(getDataInventoryItem: any()).thenReturn(true) })
//        let task2 = newTask(extraMocks: { when($0).handle(getDataInventoryItem: any()).thenReturn(false) })
//
//        peer.connected = true
//        peer.add(task: task)
//        peer.add(task: task2)
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(task).handle(getDataInventoryItem: equal(to: inv, equalWhen: { $0.hash == $1.hash }))
//        verify(task2, never()).handle(getDataInventoryItem: any())
//    }
//
//    func testConnectionDidReceiveMessage_GetDataMessage_WhenNotConnected() {
//        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 100000))
//        let message = GetDataMessage(inventoryItems: [inv])
//        let task = newTask(extraMocks: { when($0).handle(getDataInventoryItem: any()).thenReturn(true) })
//        let task2 = newTask(extraMocks: { when($0).handle(getDataInventoryItem: any()).thenReturn(false) })
//
//        peer.connected = false
//        peer.add(task: task)
//        peer.add(task: task2)
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(task, never()).handle(getDataInventoryItem: any())
//        verify(task2, never()).handle(getDataInventoryItem: any())
//    }
//
//    func testConnectionDidReceiveMessage_MerkleBlockMessage() {
//        let mockValidator = MockIMerkleBlockValidator()
//        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header, transactionHashes: [], transactions: [])
//        stub(mockValidator) { mock in
//            when(mock.merkleBlock(from: any())).thenReturn(merkleBlock)
//        }
//        stub(mockNetwork) { mock in
//            when(mock.merkleBlockValidator.get).thenReturn(mockValidator)
//        }
//
//        let message = MerkleBlockMessage(blockHeader: TestData.firstBlock.header, totalTransactions: 0, numberOfHashes: 0, hashes: [], numberOfFlags: 0, flags: [])
//        let task = newTask(extraMocks: { when($0).handle(merkleBlock: any()).thenReturn(true) })
//        let task2 = newTask(extraMocks: { when($0).handle(merkleBlock: any()).thenReturn(false) })
//
//        peer.connected = true
//        peer.add(task: task)
//        peer.add(task: task2)
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockValidator).merkleBlock(from: equal(to: message))
//        verify(task).handle(merkleBlock: equal(to: merkleBlock, equalWhen: { $0.headerHash == $1.headerHash }))
//        verify(task2, never()).handle(merkleBlock: any())
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//    func testConnectionDidReceiveMessage_MerkleBlockMessage_WhenNoInternet() {
//        let mockValidator = MockIMerkleBlockValidator()
//        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header, transactionHashes: [], transactions: [])
//        stub(mockValidator) { mock in
//            when(mock.merkleBlock(from: any())).thenReturn(merkleBlock)
//        }
//        stub(mockNetwork) { mock in
//            when(mock.merkleBlockValidator.get).thenReturn(mockValidator)
//        }
//
//        let message = MerkleBlockMessage(blockHeader: TestData.firstBlock.header, totalTransactions: 0, numberOfHashes: 0, hashes: [], numberOfFlags: 0, flags: [])
//        let task = newTask(extraMocks: { when($0).handle(merkleBlock: any()).thenReturn(true) })
//
//        peer.connected = false
//        peer.add(task: task)
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockValidator, never()).merkleBlock(from: any())
//        verify(task, never()).handle(merkleBlock: any())
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//    func testConnectionDidReceiveMessage_MerkleBlockMessage_WhenMerkleBlockNotValid() {
//        let mockValidator = MockIMerkleBlockValidator()
//        let error = MerkleBlockValidator.ValidationError.tooManyTransactions
//        stub(mockValidator) { mock in
//            when(mock.merkleBlock(from: any())).thenThrow(error)
//        }
//        stub(mockNetwork) { mock in
//            when(mock.merkleBlockValidator.get).thenReturn(mockValidator)
//        }
//
//        let message = MerkleBlockMessage(blockHeader: TestData.firstBlock.header, totalTransactions: 0, numberOfHashes: 0, hashes: [], numberOfFlags: 0, flags: [])
//        let task = newTask(extraMocks: { when($0).handle(merkleBlock: any()).thenReturn(true) })
//
//        peer.connected = true
//        peer.add(task: task)
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockValidator).merkleBlock(from: equal(to: message))
//        verify(task, never()).handle(merkleBlock: any())
//        verify(mockConnection).disconnect(error: equal(to: error, equalWhen: { type(of: $0) == type(of: $1) }))
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//    func testConnectionDidReceiveMessage_TransactionMessage() {
//        let transaction = TestData.p2pkTransaction
//        let message = TransactionMessage(transaction: transaction)
//        let task = newTask(extraMocks: { when($0).handle(transaction: any()).thenReturn(true) })
//        let task2 = newTask(extraMocks: { when($0).handle(transaction: any()).thenReturn(false) })
//
//        peer.connected = true
//        peer.add(task: task)
//        peer.add(task: task2)
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(task).handle(transaction: equal(to: transaction, equalWhen: { $0.header.dataHash == $1.header.dataHash }))
//        verify(task2, never()).handle(transaction: any())
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//    func testConnectionDidReceiveMessage_TransactionMessage_WhenNoInternet() {
//        let transaction = TestData.p2pkTransaction
//        let message = TransactionMessage(transaction: transaction)
//        let task = newTask(extraMocks: { when($0).handle(transaction: any()).thenReturn(true) })
//        let task2 = newTask(extraMocks: { when($0).handle(transaction: any()).thenReturn(false) })
//
//        peer.connected = false
//        peer.add(task: task)
//        peer.add(task: task2)
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(task, never()).handle(transaction: any())
//        verify(task2, never()).handle(transaction: any())
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//    func testConnectionDidReceiveMessage_PingMessage() {
//        let message = PingMessage(nonce: 100)
//        let pongMessage = PongMessage(nonce: 100)
//
//        peer.connected = true
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockConnection).send(message: equal(to: pongMessage, equalWhen: { ($0 as! PongMessage).nonce == ($1 as! PongMessage).nonce }))
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//    func testConnectionDidReceiveMessage_PingMessage_WhenNoInternet() {
//        let message = PingMessage(nonce: 100)
//
//        peer.connected = false
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verify(mockConnection, never()).send(message: any())
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//    func testConnectionDidReceiveMessage_RejectMessage() {
//        let message = RejectMessage(message: "", ccode: 0, reason: "", data: Data())
//
//        peer.connected = true
//        peer.connection(didReceiveMessage: message)
//        waitForMainQueue()
//
//        verifyNoMoreInteractions(mockPeerGroup)
//    }
//
//
//
//    private func listCompareFunction<T>(compareItemFunction: @escaping (T, T) -> Bool) -> ([T], [T]) -> Bool {
//        return { expected, given in
//            return given.filter { addr in
//                return !expected.contains { addr2 in
//                    return compareItemFunction(addr, addr2)
//                }
//            }.count == 0
//        }
//    }
//
//    private func resetMockConnection() {
//        reset(mockConnection)
//        stub(mockConnection) { mock in
//            when(mock.delegate.set(any())).thenDoNothing()
//            when(mock.host.get).thenReturn("")
//            when(mock.port.get).thenReturn(0)
//            when(mock.logName.get).thenReturn("")
//            when(mock).connect().thenDoNothing()
//            when(mock).disconnect(error: any()).thenDoNothing()
//            when(mock).send(message: any()).thenDoNothing()
//        }
//    }
//
//    private func newTask(extraMocks: (MockPeerTask.Stubbing) -> ()) -> MockPeerTask {
//        let mockTask = MockPeerTask()
//
//        stub(mockTask) { mock in
//            when(mock).delegate.set(any()).thenDoNothing()
//            when(mock).requester.set(any()).thenDoNothing()
//            when(mock).start().thenDoNothing()
//            extraMocks(mock)
//        }
//
//        return mockTask
//    }
//}
