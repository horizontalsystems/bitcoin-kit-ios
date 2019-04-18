//import XCTest
//import Cuckoo
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class BloomFilterManagerDelegateTests: PeerGroupTests {
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
//    func testBloomFilterUpdated() {
//        let peer = peers["0"]!
//        let bloomFilter = BloomFilter(elements: [Data(from: 10000)])
//
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([peer])
//        }
//        stub(peer) { mock in
//            when(mock.filterLoad(bloomFilter: any())).thenDoNothing()
//        }
//
//        delegate.bloomFilterUpdated(bloomFilter: bloomFilter)
//
//        verify(peer).filterLoad(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
//    }
//
//}
