//import Quick
//import Nimble
//import XCTest
//import Cuckoo
//import RealmSwift
//import RxSwift
//@testable import HSBitcoinKit
//
//class InitialSyncerTests: XCTestCase {
//
//    private var mockRealmFactory: MockIRealmFactory!
//    private var mockStateManager: MockIStateManager!
//    private var mockHDWallet: MockIHDWallet!
//    private var mockBlockDiscovery: MockIBlockDiscovery!
//    private var mockAddressManager: MockIAddressManager!
//    private var mockFactory: MockIFactory!
//    private var mockPeerGroup: MockIPeerGroup!
//    private var mockListener: MockISyncStateListener!
//    private var syncer: InitialSyncer!
//
//    private var mockReachabilityManager: MockIReachabilityManager!
//    internal var reachabilitySignal: Signal!
//
//    private var realm: Realm!
//    private var internalKeys: [PublicKey]!
//    private var externalKeys: [PublicKey]!
//    private var internalAddresses: [String]!
//    private var externalAddresses: [String]!
//
//    override func setUp() {
//        super.setUp()
//
//        mockRealmFactory = MockIRealmFactory()
//        mockHDWallet = MockIHDWallet()
//        mockStateManager = MockIStateManager()
//        mockBlockDiscovery = MockIBlockDiscovery()
//        mockAddressManager = MockIAddressManager()
//        mockFactory = MockIFactory()
//        mockPeerGroup = MockIPeerGroup()
//        mockListener = MockISyncStateListener()
//
//        reachabilitySignal = Signal()
//        mockReachabilityManager = MockIReachabilityManager()
//
//        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
//        try! realm.write { realm.deleteAll() }
//        stub(mockRealmFactory) {mock in
//            when(mock.realm.get).thenReturn(realm)
//        }
//
//        stub(mockHDWallet) { mock in
//            when(mock.gapLimit.get).thenReturn(2)
//        }
//        stub(mockAddressManager) { mock in
//            when(mock.addKeys(keys: any())).thenDoNothing()
//            when(mock.fillGap()).thenDoNothing()
//        }
//        stub(mockStateManager) { mock in
//            when(mock.restored.get).thenReturn(false)
//            when(mock.restored.set(any())).thenDoNothing()
//        }
//        stub(mockPeerGroup) { mock in
//            when(mock.start()).thenDoNothing()
//            when(mock.stop()).thenDoNothing()
//        }
//        stub(mockListener) { mock in
//            when(mock.syncStarted()).thenDoNothing()
//            when(mock.syncStopped()).thenDoNothing()
//        }
//        stub(mockReachabilityManager) { mock in
//            when(mock.reachabilitySignal.get).thenReturn(reachabilitySignal)
//            when(mock.isReachable.get).thenReturn(true)
//        }
//
//        syncer = InitialSyncer(
//                realmFactory: mockRealmFactory,
//                listener: mockListener,
//                hdWallet: mockHDWallet,
//                stateManager: mockStateManager,
//                blockDiscovery: mockBlockDiscovery,
//                addressManager: mockAddressManager,
//                factory: mockFactory,
//                peerGroup: mockPeerGroup,
//                reachabilityManager: mockReachabilityManager,
//                async: false
//        )
//    }
//
//    override func tearDown() {
//        mockRealmFactory = nil
//        mockListener = nil
//        mockHDWallet = nil
//        mockStateManager = nil
//        mockBlockDiscovery = nil
//        mockAddressManager = nil
//        mockFactory = nil
//        mockPeerGroup = nil
//        syncer = nil
//
//        reachabilitySignal = nil
//        mockReachabilityManager = nil
//
//        realm = nil
//
//        super.tearDown()
//    }
//
//    func testSync() {
////        stub(mockBlockDiscovery) { mock in
////            when(mock.discoverBlockHashes(account: 0, external: true)).thenReturn(Observable.just(([PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data())], [BlockResponse(hash: "", height: 0)])))
////            when(mock.discoverBlockHashes(account: 0, external: false)).thenReturn(Observable.just(([PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data())], [BlockResponse(hash: "", height: 0)])))
////            when(mock.discoverBlockHashes(account: 1, external: true)).thenReturn(Observable.just(([], [])))
////            when(mock.discoverBlockHashes(account: 1, external: false)).thenReturn(Observable.just(([], [])))
////        }
////        let firstBlock = TestData.firstBlock
////        let firstBlockHash = BlockHash(withHeaderHash: firstBlock.headerHash, height: 10)
////        stub(mockFactory) { mock in
////            when(mock).blockHash(withHeaderHash: any(), height: any()).thenReturn(firstBlockHash)
////        }
////        stub(mockStateManager) { mock in
////            when(mock.restored.get).thenReturn(false).thenReturn(true)
////        }
////
////        try! syncer.sync()
////
////        verify(mockPeerGroup).stop()
////        verify(mockPeerGroup).start()
////        verify(mockListener).syncStarted()
////        verify(mockAddressManager, times(2)).addKeys(keys: any())
//    }
//
//    func testStartPeerGroupIfAlreadySynced() {
//        stub(mockStateManager) { mock in
//            when(mock.restored.get).thenReturn(true)
//        }
//        stub(mockReachabilityManager) { mock in
//            when(mock.isReachable.get).thenReturn(true)
//        }
//
//        try! syncer.sync()
//
//        verify(mockPeerGroup).start()
//    }
//
//    func testApiNotSynced_BlocksDiscoveredSuccess() {
////        let externalPublicKey = PublicKey(withAccount: 0, index: 555, external: true, hdPublicKeyData: Data(hex: "e555")!)
////        let internalPublicKey = PublicKey(withAccount: 0, index: 123, external: false, hdPublicKeyData: Data(hex: "e123")!)
////
////        let externalBlocks = [BlockResponse(hash: "00", height: 110),
////                              BlockResponse(hash: "01", height: 111),
////        ]
////        let internalBlocks = [BlockResponse(hash: "10", height: 112),
////                              BlockResponse(hash: "11", height: 113),
////        ]
////
////        stub(mockBlockDiscovery) { mock in
////            when(mock.discoverBlockHashes(account: 0, external: true)).thenReturn(Observable.just(([externalPublicKey], externalBlocks)))
////            when(mock.discoverBlockHashes(account: 0, external: false)).thenReturn(Observable.just(([internalPublicKey], internalBlocks)))
////            when(mock.discoverBlockHashes(account: 1, external: true)).thenReturn(Observable.just(([], [])))
////            when(mock.discoverBlockHashes(account: 1, external: false)).thenReturn(Observable.just(([], [])))
////        }
////
////        stub(mockFactory) { mock in
////            when(mock).blockHash(withHeaderHash: equal(to: Data(hex: "00")!), height: 110).thenReturn(BlockHash(withHeaderHash: Data(hex: "00")!, height: 110))
////            when(mock).blockHash(withHeaderHash: equal(to: Data(hex: "01")!), height: 111).thenReturn(BlockHash(withHeaderHash: Data(hex: "01")!, height: 111))
////            when(mock).blockHash(withHeaderHash: equal(to: Data(hex: "10")!), height: 112).thenReturn(BlockHash(withHeaderHash: Data(hex: "10")!, height: 112))
////            when(mock).blockHash(withHeaderHash: equal(to: Data(hex: "11")!), height: 113).thenReturn(BlockHash(withHeaderHash: Data(hex: "11")!, height: 113))
////        }
////        stub(mockStateManager) { mock in
////            when(mock.restored.get).thenReturn(false).thenReturn(true)
////        }
////        try! syncer.sync()
////
////        verify(mockStateManager).restored.set(true)
////        verify(mockPeerGroup).stop()
////        verify(mockPeerGroup).start()
////
////        verify(mockAddressManager).addKeys(keys: equal(to: [externalPublicKey, internalPublicKey]))
////        verify(mockAddressManager).addKeys(keys: equal(to: []))
////
////        let actualBlocks = Array(realm.objects(BlockHash.self))
////
////        XCTAssertTrue(containsBlock(blocks: actualBlocks, hash: BlockHash(withHeaderHash: Data(hex: "00")!, height: 110)))
////        XCTAssertTrue(containsBlock(blocks: actualBlocks, hash: BlockHash(withHeaderHash: Data(hex: "01")!, height: 111)))
////        XCTAssertTrue(containsBlock(blocks: actualBlocks, hash: BlockHash(withHeaderHash: Data(hex: "10")!, height: 112)))
////        XCTAssertTrue(containsBlock(blocks: actualBlocks, hash: BlockHash(withHeaderHash: Data(hex: "11")!, height: 113)))
//    }
//
//    func testSync_ApiNotSynced_blockDiscoveredFail() {
//        stub(mockBlockDiscovery) { mock in
//            when(mock.discoverBlockHashes(account: 0, external: true)).thenReturn(Observable.error(ApiError.noConnection))
//            when(mock.discoverBlockHashes(account: 0, external: false)).thenReturn(Observable.error(ApiError.noConnection))
//        }
//
//        try! syncer.sync()
//
//        verify(mockStateManager, never()).restored.set(true)
//        verifyNoMoreInteractions(mockPeerGroup)
//
//        XCTAssertTrue(realm.objects(PublicKey.self).isEmpty)
//        XCTAssertTrue(realm.objects(BlockHash.self).isEmpty)
//    }
//
//    private func containsBlock(blocks: [BlockHash], hash: BlockHash) -> Bool {
//        return blocks.firstIndex { block in block.reversedHeaderHashHex == hash.reversedHeaderHashHex } != nil
//    }
//
//}
