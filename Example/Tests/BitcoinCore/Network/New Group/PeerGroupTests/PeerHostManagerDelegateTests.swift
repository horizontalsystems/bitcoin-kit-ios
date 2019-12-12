//import XCTest
//import Cuckoo
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class PeerHostManagerDelegateTests: PeerGroupTests {
//
//    private var delegate: PeerGroup!
//
//    override func setUp() {
//        super.setUp()
//        delegate = peerGroup
//    }
//
//    override func tearDown() {
//        delegate = nil
//        super.tearDown()
//    }
//
//    func testNewHostsAdded() {
//        peerGroup.start()
//
//        stub(mockPeerManager) { mock in
//            when(mock.totalPeersCount()).thenReturn(1)
//        }
//
//        delegate.newIpsAdded()
//        waitForMainQueue()
//
//        verify(mockPeerAddressManager).ip.get
//    }
//
//}
