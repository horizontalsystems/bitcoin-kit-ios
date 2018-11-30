import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class PeerHostManagerTests:XCTestCase {

    private var mockPeerHostManagerDelegate: MockPeerHostManagerDelegate!
    private var mockNetwork: MockINetwork!
    private var mockRealmFactory: MockIRealmFactory!
    private var mockHostDiscovery: MockIHostDiscovery!
    private var dnsLookupQueue: DispatchQueue!
    private var localQueue: DispatchQueue!
    private var hostsUsageQueue: DispatchQueue!
    private var dnsSeeds: [String]!
    private var manager: PeerHostManager!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        let configuration = Realm.Configuration(inMemoryIdentifier: "TestRealm")

        realm = try! Realm(configuration: configuration)
        try! realm.write { realm.deleteAll() }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            // We need to create new realm instances each time when requested
            // Because, we're using different DispatchQueues for localQueue and hostsUsageQueue
            when(mock.realm.get).then { return try! Realm(configuration: configuration) }
        }

        mockPeerHostManagerDelegate = MockPeerHostManagerDelegate()
        mockNetwork = MockINetwork()
        mockHostDiscovery = MockIHostDiscovery()
        dnsLookupQueue = DispatchQueue.main
        // We cannot use DispatchQueue.main because this queue has .sync calls which main thread cannot perform.
        localQueue = DispatchQueue(label: "PeerHostManager LocalQueue", qos: .background)
        hostsUsageQueue = DispatchQueue.main
        dnsSeeds = ["some.seed"]

        stub(mockHostDiscovery) { mock in
            when(mock.lookup(dnsSeed: any())).thenReturn([String]())
        }
        stub(mockNetwork) { mock in
            when(mock.dnsSeeds.get).thenReturn(dnsSeeds)
        }

        manager = PeerHostManager(network: mockNetwork, realmFactory: mockRealmFactory, hostDiscovery: mockHostDiscovery, dnsLookupQueue: localQueue, localQueue: localQueue, hostsUsageQueue: localQueue)
    }

    override func tearDown() {
        mockPeerHostManagerDelegate = nil
        mockNetwork = nil
        mockRealmFactory = nil
        mockHostDiscovery = nil
        dnsLookupQueue = nil
        localQueue = nil
        hostsUsageQueue = nil
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
        waitForMainQueue(queue: localQueue)
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
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        verify(mockHostDiscovery).lookup(dnsSeed: equal(to: dnsSeeds[0]))
    }

    func testPeerHost_HasNoPeerAddress() {
        let host = manager.peerHost
        XCTAssertEqual(host, nil)
        waitForMainQueue(queue: localQueue)
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
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        XCTAssertEqual(host, peerAddress2.ip)
    }

    func testHostDisconnected() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)

        try! realm.write {
            realm.add(peerAddress)
        }

        manager.hostDisconnected(host: peerAddress.ip, withError: nil, networkReachable: true)
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        XCTAssertEqual(peerAddress.score, 1)
    }

    func testHostDisconnected_WithError() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)

        try! realm.write {
            realm.add(peerAddress)
        }

        manager.hostDisconnected(host: peerAddress.ip, withError: PeerConnection.PeerConnectionError.connectionClosedByPeer, networkReachable: true)
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        XCTAssertEqual(realm.objects(PeerAddress.self).count, 0)
    }

    func testHostDisconnected_WithError_networkNotReachable() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)

        try! realm.write {
            realm.add(peerAddress)
        }

        manager.hostDisconnected(host: peerAddress.ip, withError: PeerConnection.PeerConnectionError.connectionClosedByPeer, networkReachable: false)
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        XCTAssertEqual(peerAddress.score, 1)
    }

    func testHostDisconnected_ShouldFreeHost() {
        let peerAddress = PeerAddress(ip: "192.168.0.1", score: 0)
        try! realm.write {
            realm.add(peerAddress)
        }

        let host = manager.peerHost
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        manager.hostDisconnected(host: host!, withError: nil, networkReachable: true)
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        let host2 = manager.peerHost
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        XCTAssertEqual(host, host2)
    }

    func testHostDisconnected_HostNotFound() {
        manager.hostDisconnected(host: "192.168.0.1", withError: nil, networkReachable: true)
        let host = manager.peerHost
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()
        XCTAssertEqual(host, nil)
    }

    func testAddHosts() {
        manager.addHosts(hosts: ["192.168.0.1", "192.168.0.2"])
        waitForMainQueue(queue: localQueue)
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
        waitForMainQueue(queue: localQueue)
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
        waitForMainQueue(queue: localQueue)
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
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()

        verify(mockPeerHostManagerDelegate).newHostsAdded()
    }

    func testAddHosts_ShouldNotCallDelegateMethodIfNoHostAdded() {
        manager.delegate = mockPeerHostManagerDelegate
        stub(mockPeerHostManagerDelegate) { mock in
            when(mock.newHostsAdded()).thenDoNothing()
        }

        manager.addHosts(hosts: [])
        waitForMainQueue(queue: localQueue)
        waitForMainQueue()

        verify(mockPeerHostManagerDelegate, never()).newHostsAdded()
    }

}
