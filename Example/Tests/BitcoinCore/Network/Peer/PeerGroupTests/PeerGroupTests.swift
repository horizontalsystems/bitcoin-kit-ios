//import XCTest
//import Cuckoo
//import RxSwift
//import Alamofire
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class PeerGroupTests: XCTestCase {
//
//    internal var mockFactory: MockIFactory!
//    internal var mockNetwork: MockINetwork!
//    internal var mockListener: MockISyncStateListener!
//    internal var mockReachabilityManager: MockIReachabilityManager!
//    internal var mockNetworkMessageParser: MockINetworkMessageParser!
//    internal var mockNetworkMessageSerializer: MockINetworkMessageSerializer!
//    internal var mockPeerAddressManager: MockIPeerAddressManager!
//    internal var mockBloomFilterManager: MockIBloomFilterManager!
//    internal var mockPeerManager: MockIPeerManager!
//    internal var mockBlockSyncer: MockIBlockSyncer!
//    internal var mockTransactionSyncer: MockITransactionSyncer!
//
//    internal var peerGroup: PeerGroup!
//
//    internal var peersCount = 3
//    internal var peers: [String: MockIPeer]!
//    internal var subject: PublishSubject<()>!
//
//    override func setUp() {
//        super.setUp()
//
//        mockFactory = MockIFactory()
//        mockNetwork = MockINetwork()
//        mockListener = MockISyncStateListener()
//        mockReachabilityManager = MockIReachabilityManager()
//        mockNetworkMessageParser = MockINetworkMessageParser()
//        mockNetworkMessageSerializer = MockINetworkMessageSerializer()
//        mockPeerAddressManager = MockIPeerAddressManager()
//        mockBloomFilterManager = MockIBloomFilterManager()
//        mockPeerManager = MockIPeerManager()
//        mockBlockSyncer = MockIBlockSyncer()
//        mockTransactionSyncer = MockITransactionSyncer()
//        peers = [String: MockIPeer]()
//        subject = PublishSubject<()>()
//
//        for host in 0..<4 {
//            let hostString = String(host)
//            let mockPeer = MockIPeer()
//            peers[hostString] = mockPeer
//
//            stub(mockFactory) { mock in
//                when(mock.peer(withHost: equal(to: hostString), network: any(), networkMessageParser: any(), networkMessageSerializer: any(), logger: any())).thenReturn(mockPeer)
//            }
//        }
//        resetStubsAndInvocationsOfPeers()
//
//        stub(mockListener) { mock in
//            when(mock.syncStarted()).thenDoNothing()
//            when(mock.syncStopped()).thenDoNothing()
//            when(mock.syncFinished()).thenDoNothing()
//        }
//        stub(mockReachabilityManager) { mock in
//            when(mock.reachabilitySignal.get).thenReturn(subject)
//            when(mock.isReachable.get).thenReturn(true)
//        }
//        stub(mockPeerAddressManager) { mock in
//            when(mock.delegate.set(any())).thenDoNothing()
//            when(mock.ip.get).thenReturn("0").thenReturn("1").thenReturn("2").thenReturn("3")
//            when(mock.markSuccess(ip: any())).thenDoNothing()
//            when(mock.markFailed(ip: any())).thenDoNothing()
//        }
//        stub(mockBloomFilterManager) { mock in
//            when(mock.delegate.set(any())).thenDoNothing()
//            when(mock.bloomFilter.get).thenReturn(nil)
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.syncPeer.get).thenReturn(nil)
//            when(mock.add(peer: any())).thenDoNothing()
//            when(mock.disconnectAll()).thenDoNothing()
//            when(mock.totalPeersCount()).thenReturn(0)
//            when(mock.someReadyPeers()).thenReturn([IPeer]())
//            when(mock.connected()).thenReturn([IPeer]())
//            when(mock.nonSyncedPeer()).thenReturn(nil)
//            when(mock.syncPeerIs(peer: any())).thenReturn(false)
//        }
//        stub(mockBlockSyncer) { mock in
//            when(mock.localDownloadedBestBlockHeight.get).thenReturn(0)
//            when(mock.localKnownBestBlockHeight.get).thenReturn(0)
//            when(mock.prepareForDownload()).thenDoNothing()
//            when(mock.downloadStarted()).thenDoNothing()
//            when(mock.downloadCompleted()).thenDoNothing()
//        }
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([FullTransaction]())
//            when(mock.handle(transactions: any())).thenDoNothing()
//            when(mock.handle(sentTransaction: any())).thenDoNothing()
//            when(mock.shouldRequestTransaction(hash: any())).thenReturn(false)
//        }
//
//        peerGroup = PeerGroup(
//                factory: mockFactory, network: mockNetwork, networkMessageParser: mockNetworkMessageParser, networkMessageSerializer: mockNetworkMessageSerializer, listener: mockListener, reachabilityManager: mockReachabilityManager, peerAddressManager: mockPeerAddressManager, bloomFilterManager: mockBloomFilterManager,
//                peerCount: peersCount, peerManager: mockPeerManager,
//                peersQueue: DispatchQueue.main, inventoryQueue: DispatchQueue.main
//        )
//        peerGroup.blockSyncer = mockBlockSyncer
//        peerGroup.transactionSyncer = mockTransactionSyncer
//    }
//
//    override func tearDown() {
//        mockFactory = nil
//        mockNetwork = nil
//        mockListener = nil
//        mockReachabilityManager = nil
//        mockPeerAddressManager = nil
//        mockBloomFilterManager = nil
//        mockBlockSyncer = nil
//        mockTransactionSyncer = nil
//
//        peerGroup = nil
//        peers = nil
//        subject = nil
//
//        super.tearDown()
//    }
//
//    internal func verifyConnectTriggeredOnlyForPeers(withHosts hosts: [String]) {
//        for (host, peer) in peers {
//            if hosts.contains(where: { expectedHost in return expectedHost == host }) {
//                verify(peer).connect()
//            } else {
//                verify(peer, never()).connect()
//            }
//        }
//    }
//
//    // Other Helper Methods
//
//    internal func resetStubsAndInvocationsOfPeers() {
//        for (host, mockPeer) in peers {
//            reset(mockPeer)
//
//            stub(mockPeer) { mock in
//                when(mock.announcedLastBlockHeight.get).thenReturn(0)
//                when(mock.localBestBlockHeight.get).thenReturn(0)
//                when(mock.localBestBlockHeight.set(any())).thenDoNothing()
//                when(mock.logName.get).thenReturn(host)
//                when(mock.ready.get).thenReturn(false)
//                when(mock.synced.get).thenReturn(false)
//                when(mock.blockHashesSynced.get).thenReturn(false)
//                when(mock.delegate.set(any())).thenDoNothing()
//                when(mock.host.get).thenReturn(host)
//
//                when(mock.connect()).thenDoNothing()
//                when(mock.disconnect(error: any())).thenDoNothing()
//                when(mock.add(task: any())).thenDoNothing()
//                when(mock.isRequestingInventory(hash: any())).thenReturn(false)
//                when(mock.filterLoad(bloomFilter: any())).thenDoNothing()
//
//                when(mock.equalTo(equal(to: mockPeer, equalWhen: { $0?.host == $1?.host }))).thenReturn(true)
//                when(mock.equalTo(equal(to: mockPeer, equalWhen: { $0?.host != $1?.host }))).thenReturn(false)
//            }
//        }
//    }
//
//}
