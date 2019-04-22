//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class PeerAddressManagerTests: XCTestCase {
//    private var mockStorage: MockIStorage!
//    private var mockNetwork: MockINetwork!
//    private var mockPeerDiscovery: MockIPeerDiscovery!
//    private var mockState: MockPeerAddressManagerState!
//    private var mockDelegate: MockIPeerAddressManagerDelegate!
//
//    private var manager: PeerAddressManager!
//
//    override func setUp() {
//        super.setUp()
//
//        mockStorage = MockIStorage()
//        mockNetwork = MockINetwork()
//        mockPeerDiscovery = MockIPeerDiscovery()
//        mockState = MockPeerAddressManagerState()
//        mockDelegate = MockIPeerAddressManagerDelegate()
//
//        manager = PeerAddressManager(
//                storage: mockStorage,
//                network: mockNetwork,
//                peerDiscovery: mockPeerDiscovery,
//                state: mockState
//        )
//        manager.delegate = mockDelegate
//    }
//
//    override func tearDown() {
//        mockStorage = nil
//        mockNetwork = nil
//        mockPeerDiscovery = nil
//        mockState = nil
//        mockDelegate = nil
//
//        manager = nil
//
//        super.tearDown()
//    }
//
//    func testIp_hasPeerAddress() {
//        let address = PeerAddress(ip: "1.1.1.1", score: 0)
//        let usedIps = ["2.2.2.2"]
//
//        stub(mockState) { mock in
//            when(mock.usedIps.get).thenReturn(usedIps)
//            when(mock.add(usedIp: any())).thenDoNothing()
//        }
//        stub(mockStorage) { mock in
//            when(mock.leastScorePeerAddress(excludingIps: equal(to: usedIps))).thenReturn(address)
//        }
//
//        XCTAssertEqual(manager.ip, address.ip)
//
//        verify(mockState).add(usedIp: address.ip)
//    }
//
//    func testIp_noPeerAddress() {
//        let usedIps = ["1.1.1.1"]
//        let seed1 = "abc.com"
//        let seed2 = "def.com"
//
//        stub(mockNetwork) { mock in
//            when(mock.dnsSeeds.get).thenReturn([seed1, seed2])
//        }
//        stub(mockState) { mock in
//            when(mock.usedIps.get).thenReturn(usedIps)
//        }
//        stub(mockStorage) { mock in
//            when(mock.leastScorePeerAddress(excludingIps: equal(to: usedIps))).thenReturn(nil)
//        }
//        stub(mockPeerDiscovery) { mock in
//            when(mock.lookup(dnsSeed: any())).thenDoNothing()
//        }
//
//        XCTAssertNil(manager.ip)
//
//        verify(mockPeerDiscovery).lookup(dnsSeed: seed1)
//        verify(mockPeerDiscovery).lookup(dnsSeed: seed2)
//    }
//
//    func testMarkSuccess() {
//        let ip = "1.1.1.1"
//
//        stub(mockState) { mock in
//            when(mock.remove(usedIp: any())).thenDoNothing()
//        }
//        stub(mockStorage) { mock in
//            when(mock.increasePeerAddressScore(ip: any())).thenDoNothing()
//        }
//
//        manager.markSuccess(ip: ip)
//
//        verify(mockState).remove(usedIp: ip)
//        verify(mockStorage).increasePeerAddressScore(ip: ip)
//    }
//
//    func testMarkFailed() {
//        let ip = "1.1.1.1"
//
//        stub(mockState) { mock in
//            when(mock.remove(usedIp: any())).thenDoNothing()
//        }
//        stub(mockStorage) { mock in
//            when(mock.deletePeerAddress(byIp: any())).thenDoNothing()
//        }
//
//        manager.markFailed(ip: ip)
//
//        verify(mockState).remove(usedIp: ip)
//        verify(mockStorage).deletePeerAddress(byIp: ip)
//    }
//
//    func testAddIps() {
//        let ip1 = "1.1.1.1"
//        let ip2 = "2.2.2.2"
//        let ip3 = "3.3.3.3"
//        let ip3_2 = "3.3.3.3"
//        let existingAddresses = [PeerAddress(ip: ip1, score: 0)]
//        let ips = [ip1, ip2, ip3, ip3_2]
//
//        stub(mockStorage) { mock in
//            when(mock.existingPeerAddresses(fromIps: equal(to: ips))).thenReturn(existingAddresses)
//            when(mock.save(peerAddresses: any())).thenDoNothing()
//        }
//        stub(mockDelegate) { mock in
//            when(mock.newIpsAdded()).thenDoNothing()
//        }
//
//        manager.add(ips: ips)
//
//        let argumentCaptor = ArgumentCaptor<[PeerAddress]>()
//
//        verify(mockStorage).save(peerAddresses: argumentCaptor.capture())
//        verify(mockDelegate).newIpsAdded()
//
//        XCTAssertEqual(argumentCaptor.value!.count, 2)
//        XCTAssertTrue(argumentCaptor.value!.contains(PeerAddress(ip: ip2, score: 0)))
//        XCTAssertTrue(argumentCaptor.value!.contains(PeerAddress(ip: ip3, score: 0)))
//    }
//
//}
