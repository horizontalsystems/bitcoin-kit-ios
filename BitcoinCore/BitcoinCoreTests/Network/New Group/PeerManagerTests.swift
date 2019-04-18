//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class PeerManagerTests:XCTestCase {
//
//    private var manager: PeerManager!
//
//    override func setUp() {
//        super.setUp()
//
//        manager = PeerManager()
//    }
//
//    override func tearDown() {
//        manager = nil
//
//        super.tearDown()
//    }
//
//    func testAdd() {
//        manager.add(peer: MockIPeer())
//        XCTAssertEqual(manager.totalPeersCount(), 1)
//    }
//
//    func testDisconnectAll() {
//        let peer = addPeer(host: "0")
//        let peer2 = addPeer(host: "1")
//
//        manager.disconnectAll()
//        verify(peer).disconnect(error: isNil())
//        verify(peer2).disconnect(error: isNil())
//    }
//
//    func testSomeReadyPeers() {
//        let peer = addPeer(host: "0", ready: true)
//        let _ = addPeer(host: "1", ready: true)
//        let _ = addPeer(host: "3", ready: false)
//
//        let peers = manager.someReadyPeers()
//        XCTAssertEqual(peers.count, 1)
//        XCTAssertEqual(peers.first!.host, peer.host)
//    }
//
//    func testSomeReadyPeers_NoPeers() {
//        let peers = manager.someReadyPeers()
//        XCTAssertEqual(peers.count, 0)
//    }
//
//    func testSomeReadyPeers_OnePeer() {
//        let peer = addPeer(host: "0", ready: true)
//        let peers = manager.someReadyPeers()
//        XCTAssertEqual(peers.count, 1)
//        XCTAssertEqual(peers.first!.host, peer.host)
//    }
//
//    func testConnected() {
//        let peer = addPeer(host: "0", connected: true)
//        let _ = addPeer(host: "1", connected: false)
//
//        let peers = manager.connected()
//        XCTAssertEqual(peers.count, 1)
//        XCTAssertEqual(peers.first!.host, peer.host)
//    }
//
//    func testNonSyncedPeer() {
//        let peer = addPeer(host: "0", connected: true, synced: false)
//        let _ = addPeer(host: "1", connected: true, synced: true)
//        let _ = addPeer(host: "2", connected: false, synced: false)
//        let _ = addPeer(host: "3", connected: false, synced: true)
//
//        let resultPeer = manager.nonSyncedPeer()
//        XCTAssertEqual(resultPeer!.host, peer.host)
//    }
//
//    func testSyncPeerIs() {
//        let peer = addPeer(host: "0", connected: true, synced: false)
//        manager.syncPeer = peer
//
//        stub(peer) { mock in
//            when(mock.equalTo(any())).thenReturn(true)
//        }
//
//        XCTAssertEqual(manager.syncPeerIs(peer: peer), true)
//
//        stub(peer) { mock in
//            when(mock.equalTo(any())).thenReturn(false)
//        }
//
//        XCTAssertEqual(manager.syncPeerIs(peer: peer), false)
//    }
//
//    func testHalfIsSynced() {
//        let _ = addPeer(host: "0", connected: true, synced: true)
//        let _ = addPeer(host: "1", connected: true, synced: true)
//        let _ = addPeer(host: "2", connected: false, synced: false)
//        let _ = addPeer(host: "3", connected: false, synced: true)
//
//        XCTAssertEqual(manager.halfIsSynced(), true)
//    }
//
//    func testHalfIsSynced_MoreThanHalf() {
//        let _ = addPeer(host: "0", connected: true, synced: true)
//
//        XCTAssertEqual(manager.halfIsSynced(), true)
//    }
//
//    func testHalfIsSynced_LessThanHalf() {
//        print("ere")
//        let _ = addPeer(host: "0", connected: true, synced: true)
//        let _ = addPeer(host: "1", connected: true, synced: false)
//        let _ = addPeer(host: "2", connected: false, synced: false)
//        let _ = addPeer(host: "3", connected: false, synced: true)
//
//        XCTAssertEqual(manager.halfIsSynced(), false)
//    }
//
//    private func addPeer(host: String, ready: Bool = false, connected: Bool = false, synced: Bool = false) -> MockIPeer {
//        let peer = MockIPeer()
//
//        stub(peer) { mock in
//            when(mock.host.get).thenReturn(host)
//            when(mock.ready.get).thenReturn(ready)
//            when(mock.connected.get).thenReturn(connected)
//            when(mock.synced.get).thenReturn(synced)
//            when(mock.disconnect(error: any())).thenDoNothing()
//        }
//
//        manager.add(peer: peer)
//
//        return peer
//    }
//
//}
