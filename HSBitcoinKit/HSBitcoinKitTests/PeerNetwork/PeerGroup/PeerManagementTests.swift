import XCTest
import Cuckoo
import RealmSwift
import HSHDWalletKit
import RxSwift
import Alamofire
@testable import HSBitcoinKit

class PeerManagementTests: XCTestCase {

    private var mockFactory: MockIFactory!
    private var mockNetwork: MockINetwork!
    private var mockBestBlockHeightListener: MockBestBlockHeightListener!
    private var mockReachabilityManager: MockIReachabilityManager!
    private var mockPeerHostManager: MockIPeerHostManager!
    private var mockBloomFilterManager: MockIBloomFilterManager!

    private var peerGroup: PeerGroup!

    private var peers: [String: MockIPeer]!
    private var subject: PublishSubject<NetworkReachabilityManager.NetworkReachabilityStatus>!
    private var publicKey: PublicKey!

    override func setUp() {
        super.setUp()

        mockFactory = MockIFactory()
        mockNetwork = MockINetwork()
        mockBestBlockHeightListener = MockBestBlockHeightListener()
        mockReachabilityManager = MockIReachabilityManager()
        mockPeerHostManager = MockIPeerHostManager()
        mockBloomFilterManager = MockIBloomFilterManager()
        peers = [String: MockIPeer]()
        subject = PublishSubject<NetworkReachabilityManager.NetworkReachabilityStatus>()

        for host in 0..<4 {
            let hostString = String(host)
            let mockPeer = MockIPeer()
            peers[hostString] = mockPeer

            stub(mockPeer) { mock in
                when(mock.logName.get).thenReturn(hostString)
                when(mock.ready.get).thenReturn(false)
                when(mock.synced.get).thenReturn(false)
                when(mock.blockHashesSynced.get).thenReturn(false)
                when(mock.delegate.set(any())).thenDoNothing()
                when(mock.announcedLastBlockHeight.get).thenReturn(0)
                when(mock.localBestBlockHeight.set(any())).thenDoNothing()
                when(mock.host.get).thenReturn(hostString)

                when(mock.connect()).thenDoNothing()
                when(mock.disconnect(error: any())).thenDoNothing()
                when(mock.add(task: any())).thenDoNothing()
                when(mock.isRequestingInventory(hash: any())).thenReturn(false)
                when(mock.handleRelayedTransaction(hash: any())).thenReturn(false)
                when(mock.filterLoad(bloomFilter: any())).thenDoNothing()

                when(mock.equalTo(equal(to: mockPeer, equalWhen: { $0?.host == $1?.host }))).thenReturn(true)
                when(mock.equalTo(equal(to: mockPeer, equalWhen: { $0?.host != $1?.host }))).thenReturn(false)
            }
            stub(mockFactory) { mock in
                when(mock.peer(withHost: equal(to: hostString), network: any())).thenReturn(mockPeer)
            }
        }

        let hdWallet: IHDWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        let hdPrivKeyData = try! hdWallet.privateKeyData(index: 0, external: true)
        publicKey = PublicKey(withIndex: 0, external: true, hdPublicKeyData: hdPrivKeyData)

        stub(mockBestBlockHeightListener) { mock in
            when(mock.bestBlockHeightReceived(height: any())).thenDoNothing()
        }
        stub(mockReachabilityManager) { mock in
            when(mock.subject.get).thenReturn(subject)
            when(mock.reachable()).thenReturn(true)
        }
        stub(mockPeerHostManager) { mock in
            when(mock.delegate.set(any())).thenDoNothing()
            when(mock.peerHost.get).thenReturn("0").thenReturn("1").thenReturn("2").thenReturn("3")
            when(mock.hostDisconnected(host: any(), withError: any(), networkReachable: any())).thenDoNothing()
        }
        stub(mockBloomFilterManager) { mock in
            when(mock.delegate.set(any())).thenDoNothing()
            when(mock.bloomFilter.get).thenReturn(nil)
        }

        peerGroup = PeerGroup(
                factory: mockFactory, network: mockNetwork, listener: mockBestBlockHeightListener, reachabilityManager: mockReachabilityManager, peerHostManager: mockPeerHostManager, bloomFilterManager: mockBloomFilterManager, peerCount: 3,
                localQueue: DispatchQueue.main, syncPeerQueue: DispatchQueue.main, inventoryQueue: DispatchQueue.main
        )
    }

    override func tearDown() {
        mockFactory = nil
        mockNetwork = nil
        mockBestBlockHeightListener = nil
        mockReachabilityManager = nil
        mockPeerHostManager = nil
        mockBloomFilterManager = nil
        peerGroup = nil

        peers = nil
        subject = nil
        publicKey = nil

        super.tearDown()
    }

    func testStart_TriggerConnection() {
        peerGroup.start()
        waitForMainQueue()
        verify(mockPeerHostManager, times(3)).peerHost.get
        verify(peers["0"]!).connect()
        verify(peers["1"]!).connect()
        verify(peers["2"]!).connect()
        verify(peers["3"]!, never()).connect()
    }

    func testStart_OnlyOneProcessAtATime() {
        stub(mockPeerHostManager) { mock in
            when(mock.peerHost.get).thenReturn(nil)
        }
        peerGroup.start()
        peerGroup.start()
        waitForMainQueue()
        verify(mockPeerHostManager, times(1)).peerHost.get
        peerGroup.start()
        waitForMainQueue()
        verify(mockPeerHostManager, times(1)).peerHost.get
    }

    func testStart_ConnectingPeersShouldBeCounted() {
        stub(mockPeerHostManager) { mock in
            when(mock.peerHost.get).thenReturn("0").thenReturn("1").thenReturn(nil).thenReturn("2")
        }
        peerGroup.start()
        waitForMainQueue()
        verify(mockPeerHostManager, times(3)).peerHost.get
        verify(peers["0"]!).connect()
        verify(peers["1"]!).connect()
        verify(peers["2"]!, never()).connect()

        peerGroup.peerDidDisconnect(peers["0"]!, withError: nil)
        waitForMainQueue()
        verify(mockPeerHostManager, times(1)).peerHost.get
        verify(peers["2"]!).connect()
        verify(peers["3"]!, never()).connect()
    }

    func testPeerDidConnect() {
        peerGroup.start()
        peerGroup.peerDidConnect(peers["0"]!)
        waitForMainQueue()
        testConnectedPeersList([peers["0"]!])

        peerGroup.peerDidDisconnect(peers["0"]!, withError: nil)
        waitForMainQueue()
        verify(mockPeerHostManager, never()).peerHost.get
    }


    private func testConnectedPeersList(_ expectedPeers: [MockIPeer]) {
        let bloomFilter = BloomFilter(elements: [Data(from: 10000000000000)])
        peerGroup.bloomFilterUpdated(bloomFilter: bloomFilter)

        for (host, peer) in peers {
            if expectedPeers.contains(where: { expectedPeer in return expectedPeer.host == host }) {
                verify(peer).filterLoad(bloomFilter: any())
            } else {
                verify(peer, never()).filterLoad(bloomFilter: any())
            }
        }
    }
}
