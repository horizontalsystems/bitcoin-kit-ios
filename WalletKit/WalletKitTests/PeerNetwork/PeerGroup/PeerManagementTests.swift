//import XCTest
//import Cuckoo
//import RealmSwift
//@testable import WalletKit
//
//class PeerManagementTests: XCTestCase {
//
//    private var mockWalletKit: MockWalletKit!
//    private var mockPeerHostManager: MockPeerHostManager!
//    private var mockFactory: MockFactory!
//    private var peerGroup: PeerGroup!
//    private var peers: [String: MockPeer]!
//    private var publicKey: PublicKey!
//
//    override func setUp() {
//        super.setUp()
//
//        mockWalletKit = MockWalletKit()
//        mockPeerHostManager = mockWalletKit.mockPeerHostManager
//        mockFactory = mockWalletKit.mockFactory
//        peers = [
//            "0.0.0.0": MockPeer(host: "0.0.0.0", network: mockWalletKit.mockNetwork),
//            "0.0.0.1": MockPeer(host: "0.0.0.1", network: mockWalletKit.mockNetwork),
//            "0.0.0.2": MockPeer(host: "0.0.0.2", network: mockWalletKit.mockNetwork),
//            "0.0.0.3": MockPeer(host: "0.0.0.3", network: mockWalletKit.mockNetwork)
//        ]
//        let privateKey = HDPrivateKey(privateKey: Data(hex: "6a787b30bd81c8fa5ed09175b5fb08e179cf429ba91ca649dd3317436b7b698e")!, chainCode: Data(), network: MockWalletKit().mockNetwork)
//        publicKey = PublicKey(withIndex: 0, external: true, hdPublicKey: privateKey.publicKey())
//
//        stub(mockPeerHostManager) { mock in
//            when(mock.peerHost.get).thenReturn("0.0.0.0").thenReturn("0.0.0.1").thenReturn("0.0.0.2").thenReturn("0.0.0.3")
//        }
//
//        for (host, peer) in peers {
//            stub(peer) { mock in
//                when(mock.delegate.set(any())).thenDoNothing()
//                when(mock.connect()).thenDoNothing()
//                when(mock.host.get).thenReturn(host)
//                when(mock.addFilter(filter: any())).thenDoNothing()
//            }
//            stub(mockFactory) { mock in
//                when(mock.peer(withHost: equal(to: host), network: any())).thenReturn(peer)
//            }
//        }
//
//        peerGroup = PeerGroup(
//                factory: mockWalletKit.mockFactory, network: mockWalletKit.mockNetwork, peerHostManager: mockWalletKit.mockPeerHostManager, bloomFilters: [Data](), peerCount: 3,
//                localQueue: DispatchQueue.main, syncPeerQueue: DispatchQueue.main, inventoryQueue: DispatchQueue.main
//        )
//    }
//
//    override func tearDown() {
//        mockWalletKit = nil
//        mockPeerHostManager = nil
//        mockFactory = nil
//        peerGroup = nil
//        peers = nil
//
//        super.tearDown()
//    }
//
//    func testStart_TriggerConnection() {
//        peerGroup.start()
//        waitForMainQueue()
//        verify(mockPeerHostManager, times(3)).peerHost.get
//        verify(peers["0.0.0.0"]!).connect()
//        verify(peers["0.0.0.1"]!).connect()
//        verify(peers["0.0.0.2"]!).connect()
//        verify(peers["0.0.0.3"]!, never()).connect()
//    }
//
//    func testStart_OnlyOneProcessAtATime() {
//        stub(mockPeerHostManager) { mock in
//            when(mock.peerHost.get).thenReturn(nil)
//        }
//        peerGroup.start()
//        peerGroup.start()
//        waitForMainQueue()
//        verify(mockPeerHostManager, times(1)).peerHost.get
//        peerGroup.start()
//        waitForMainQueue()
//        verify(mockPeerHostManager, times(1)).peerHost.get
//    }
//
//    func testStart_ConnectingPeersShouldBeCounted() {
//        stub(mockPeerHostManager) { mock in
//            when(mock.peerHost.get).thenReturn("0.0.0.0").thenReturn("0.0.0.1").thenReturn(nil).thenReturn("0.0.0.2")
//        }
//        peerGroup.start()
//        waitForMainQueue()
//        verify(mockPeerHostManager, times(3)).peerHost.get
//        verify(peers["0.0.0.0"]!).connect()
//        verify(peers["0.0.0.1"]!).connect()
//        verify(peers["0.0.0.2"]!, never()).connect()
//
//        peerGroup.peerDidDisconnect(peers["0.0.0.0"]!, withError: false)
//        waitForMainQueue()
//        verify(mockPeerHostManager, times(1)).peerHost.get
//        verify(peers["0.0.0.2"]!).connect()
//        verify(peers["0.0.0.3"]!, never()).connect()
//    }
//
//    func testPeerDidConnect() {
//        peerGroup.start()
//        peerGroup.peerDidConnect(peers["0.0.0.0"]!)
//        waitForMainQueue()
//        testConnectedPeersList([peers["0.0.0.0"]!])
//
//        peerGroup.peerDidDisconnect(peers["0.0.0.0"]!, withError: false)
//        waitForMainQueue()
//        verify(mockPeerHostManager, never()).peerHost.get
//    }
//
//
//    private func testConnectedPeersList(_ expectedPeers: [MockPeer]) {
//        peerGroup.addPublicKeyFilter(pubKey: publicKey)
//
//        for (host, peer) in peers {
//            if expectedPeers.contains(where: { expectedPeer in
//                return expectedPeer.host == host
//            }) {
//                verify(peer, times(2)).addFilter(filter: any())
//            } else {
//                verify(peer, never()).addFilter(filter: any())
//            }
//        }
//    }
//}
