import XCTest
import Cuckoo
import RealmSwift
import HSHDWalletKit
@testable import HSBitcoinKit

class PeerHostManagerDelegateTests: PeerGroupTests {

    private var delegate: PeerGroup!

    override func setUp() {
        super.setUp()
        delegate = peerGroup
    }

    override func tearDown() {
        delegate = nil
        super.tearDown()
    }

    func testNewHostsAdded() {
        peerGroup.start()

        stub(mockPeers) { mock in
            when(mock.totalPeersCount()).thenReturn(1)
        }

        delegate.newHostsAdded()
        waitForMainQueue()

        verify(mockPeerHostManager).peerHost.get
    }

}
