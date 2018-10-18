import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class PeerHostManagerTests:XCTestCase {

    private var mockPeerHostManagerDelegate: MockPeerHostManagerDelegate!
    private var mockNetwork: MockINetwork!
    private var mockRealmFactory: MockIRealmFactory!
    private var mockHostDiscovery: MockIHostDiscovery!
    private var queue: DispatchQueue!
    private var dnsSeeds: [String]!
    private var manager: PeerHostManager!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockPeerHostManagerDelegate = MockPeerHostManagerDelegate()
        mockNetwork = MockINetwork()
        mockHostDiscovery = MockIHostDiscovery()
        queue = DispatchQueue.main
        dnsSeeds = ["some.seed"]

        stub(mockHostDiscovery) { mock in
            when(mock.lookup(dnsSeed: any())).thenReturn([String]())
        }
        stub(mockNetwork) { mock in
            when(mock.dnsSeeds.get).thenReturn(dnsSeeds)
        }

        manager = PeerHostManager(network: mockNetwork, realmFactory: mockRealmFactory, hostDiscovery: mockHostDiscovery, dnsLookupQueue: queue, localQueue: queue)
    }

    override func tearDown() {
        mockPeerHostManagerDelegate = nil
        mockNetwork = nil
        mockRealmFactory = nil
        mockHostDiscovery = nil
        queue = nil
        manager = nil
        realm = nil

        super.tearDown()
    }

    func testPeerHost_HasFreePeerAddress() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)

        try! realm.write {
            realm.add(peerAddress)
        }

        let host = manager.peerHost
        XCTAssertEqual(host, peerAddress.ip)
        waitForMainQueue()
        verify(mockHostDiscovery, never()).lookup(dnsSeed: any())
    }

    func testPeerHost_HasNoFreePeerAddress() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)

        try! realm.write {
            realm.add(peerAddress)
        }

        let _ = manager.peerHost
        let host2 = manager.peerHost
        XCTAssertEqual(host2, nil)
        waitForMainQueue()
        verify(mockHostDiscovery).lookup(dnsSeed: equal(to: dnsSeeds[0]))
    }

    func testPeerHost_HasNoPeerAddress() {
        let host = manager.peerHost
        XCTAssertEqual(host, nil)
        waitForMainQueue()
        verify(mockHostDiscovery).lookup(dnsSeed: equal(to: dnsSeeds[0]))
    }

    func testPeerHost_ShouldReturnAddressWithLowestScore() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 1)
        let peerAddress2 = PeerAddress(ip: "192.168.0.2", score: 0)

        try! realm.write {
            realm.add(peerAddress)
            realm.add(peerAddress2)
        }

        let host = manager.peerHost
        waitForMainQueue()
        XCTAssertEqual(host, peerAddress2.ip)
    }

    func testHostDisconnected() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)

        try! realm.write {
            realm.add(peerAddress)
        }

        manager.hostDisconnected(host: peerAddress.ip, withError: false)
        waitForMainQueue()
        XCTAssertEqual(peerAddress.score, 1)
    }

    func testHostDisconnected_WithError() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)

        try! realm.write {
            realm.add(peerAddress)
        }

        manager.hostDisconnected(host: peerAddress.ip, withError: true)
        waitForMainQueue()
        XCTAssertEqual(realm.objects(PeerAddress.self).count, 0)
    }

    func testHostDisconnected_ShouldFreeHost() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)
        try! realm.write {
            realm.add(peerAddress)
        }

        let host = manager.peerHost
        waitForMainQueue()
        manager.hostDisconnected(host: host!, withError: false)
        waitForMainQueue()
        let host2 = manager.peerHost
        waitForMainQueue()
        XCTAssertEqual(host, host2)
    }

    func testHostDisconnected_HostNotFound() {
        manager.hostDisconnected(host: "192.168.0.1", withError: false)
        let host = manager.peerHost
        waitForMainQueue()
        XCTAssertEqual(host, nil)
    }

    func testAddHosts() {
        manager.addHosts(hosts: ["192.168.0.1", "192.168.0.2"])
        waitForMainQueue()

        XCTAssertEqual(realm.objects(PeerAddress.self).count, 2)
        var peerAddress = realm.objects(PeerAddress.self).first!
        XCTAssertEqual(peerAddress.ip, "192.168.0.1")
        XCTAssertEqual(peerAddress.score, 0)
        peerAddress = realm.objects(PeerAddress.self).last!
        XCTAssertEqual(peerAddress.ip, "192.168.0.2")
        XCTAssertEqual(peerAddress.score, 0)
    }

    func testAddHosts_ShouldAddOnlyNewHosts() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)
        try! realm.write {
            realm.add(peerAddress)
        }

        manager.addHosts(hosts: ["192.168.0.1", "192.168.0.2"])
        waitForMainQueue()

        XCTAssertEqual(realm.objects(PeerAddress.self).count, 2)
        var newPeerAddress = realm.objects(PeerAddress.self).first!
        XCTAssertEqual(newPeerAddress.ip, "192.168.0.1")
        XCTAssertEqual(newPeerAddress.score, 0)
        newPeerAddress = realm.objects(PeerAddress.self).last!
        XCTAssertEqual(newPeerAddress.ip, "192.168.0.2")
        XCTAssertEqual(newPeerAddress.score, 0)
    }

    func testAddHosts_ShouldHandleDuplicates() {
        manager.addHosts(hosts: ["192.168.0.1", "192.168.0.1"])
        waitForMainQueue()

        XCTAssertEqual(realm.objects(PeerAddress.self).count, 1)
        let newPeerAddress = realm.objects(PeerAddress.self).first!
        XCTAssertEqual(newPeerAddress.ip, "192.168.0.1")
        XCTAssertEqual(newPeerAddress.score, 0)
    }

    func testAddHosts_ShouldCallDelegateMethod() {
        manager.delegate = mockPeerHostManagerDelegate
        stub(mockPeerHostManagerDelegate) { mock in
            when(mock.newHostsAdded()).thenDoNothing()
        }

        manager.addHosts(hosts: ["192.168.0.1"])
        waitForMainQueue()

        verify(mockPeerHostManagerDelegate).newHostsAdded()
    }

    func testAddHosts_ShouldNotCallDelegateMethodIfNoHostAdded() {
        manager.delegate = mockPeerHostManagerDelegate
        stub(mockPeerHostManagerDelegate) { mock in
            when(mock.newHostsAdded()).thenDoNothing()
        }

        manager.addHosts(hosts: [])
        waitForMainQueue()

        verify(mockPeerHostManagerDelegate, never()).newHostsAdded()
    }

}
