//import XCTest
//import Cuckoo
//import HSHDWalletKit
//@testable import BitcoinCore
//
//class IPeerGroupTests: PeerGroupTests {
//
//    // For all tests peersCount = 3
//
//    func testStart() {
//        peerGroup.start()
//        waitForMainQueue()
//
//        verify(mockBlockSyncer).prepareForDownload()
//        verify(mockListener).syncStarted()
//        let expectedConnectTriggeredHosts = Array(peers.keys.sorted().prefix(peersCount))
//        verify(mockPeerAddressManager, times(peersCount)).ip.get
//        verifyConnectTriggeredOnlyForPeers(withHosts: expectedConnectTriggeredHosts)
//
//        for host in expectedConnectTriggeredHosts {
//            let peerMock = peers[host]!
//            verify(peerMock).delegate.set(any())
//            verify(peerMock).localBestBlockHeight.set(equal(to: 0))
//            verify(mockPeerManager).add(peer: equal(to: peerMock, equalWhen: { $0!.host == $1.host }))
//        }
//    }
//
//    func testStart_OnlyOneProcessAtATime() {
//        // First time
//        stub(mockPeerAddressManager) { mock in
//            when(mock.ip.get).thenReturn(nil)
//        }
//
//        peerGroup.start()
//        waitForMainQueue()
//
//        verify(mockPeerAddressManager, times(1)).ip.get
//
//        // Second time
//        reset(mockPeerAddressManager)
//        stub(mockPeerAddressManager) { mock in
//            when(mock.ip.get).thenReturn(nil)
//        }
//
//        peerGroup.start()
//        waitForMainQueue()
//
//        verify(mockPeerAddressManager, never()).ip.get
//
//        // But if you stop and start again
//        reset(mockPeerAddressManager)
//        stub(mockPeerAddressManager) { mock in
//            when(mock.ip.get).thenReturn(nil)
//        }
//
//        peerGroup.stop()
//        peerGroup.start()
//        waitForMainQueue()
//
//        verify(mockPeerAddressManager, times(1)).ip.get
//    }
//
//    func testStart_AddedPeersIsEqualToPeersCount() {
//        stub(mockPeerManager) { mock in
//            when(mock.totalPeersCount()).thenReturn(peersCount)
//        }
//        peerGroup.start()
//        waitForMainQueue()
//
//        verify(mockPeerAddressManager, never()).ip.get
//        verifyConnectTriggeredOnlyForPeers(withHosts: [])
//    }
//
//    func testStart_SubscribeToReachabilityManager() {
//        XCTAssertEqual(subject.hasObservers, false)
//        peerGroup.start()
//        waitForMainQueue()
//        XCTAssertEqual(subject.hasObservers, true)
//    }
//
//    func testReachabilityChanged_Connected() {
//        peerGroup.start()
//        waitForMainQueue()
//
//        subject.onNext(())
//        stub(mockReachabilityManager) { mock in
//            when(mock.isReachable.get).thenReturn(true)
//        }
//        verify(mockBlockSyncer).prepareForDownload()
//        verify(mockListener).syncStarted()
//    }
//
//    func testReachabilityChanged_Disconnected() {
//        peerGroup.start()
//        waitForMainQueue()
//
//        stub(mockReachabilityManager) { mock in
//            when(mock.isReachable.get).thenReturn(false)
//        }
//        subject.onNext(())
//
//        verify(mockPeerManager).disconnectAll()
//        verify(mockListener).syncStopped()
//    }
//
//
//    func testStart_NetworkIsNotReachable() {
//        stub(mockReachabilityManager) { mock in
//            when(mock.isReachable.get).thenReturn(false)
//        }
//
//        peerGroup.start()
//        waitForMainQueue()
//
//        verify(mockPeerAddressManager, never()).ip.get
//        verifyConnectTriggeredOnlyForPeers(withHosts: [])
//    }
//
//    func testStop() {
//        peerGroup.stop()
//        verify(mockPeerManager).disconnectAll()
//        verify(mockListener).syncStopped()
//    }
//
//    func testSendPendingTransactions() {
//        let transaction = TestData.p2pkTransaction
//        let peer = peers["0"]!
//
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([transaction])
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([peer])
//            when(mock.halfIsSynced()).thenReturn(true)
//            when(mock.someReadyPeers()).thenReturn([peer])
//        }
//
//        try! peerGroup.sendPendingTransactions()
//        waitForMainQueue()
//
//        verify(peer).add(task: equal(to: SendTransactionTask(transaction: transaction)))
//    }
//
//    func testSendPendingTransactions_NoConnectedPeers() {
//        let transaction = TestData.p2pkTransaction
//        let peer = peers["0"]!
//
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([transaction])
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([])
//            when(mock.halfIsSynced()).thenReturn(true)
//            when(mock.someReadyPeers()).thenReturn([peer])
//        }
//
//        do {
//            try peerGroup.sendPendingTransactions()
//            waitForMainQueue()
//            XCTFail("Should throw exception")
//        } catch let error as PeerGroup.PeerGroupError {
//            XCTAssertEqual(error, PeerGroup.PeerGroupError.noConnectedPeers)
//        } catch {
//            XCTFail("Unexpected exception thrown")
//        }
//
//        verify(peer, never()).add(task: any())
//    }
//
//    func testSendPendingTransactions_MajorityOfPeersAreNotSynced() {
//        let transaction = TestData.p2pkTransaction
//        let peer = peers["0"]!
//
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([transaction])
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([peer])
//            when(mock.halfIsSynced()).thenReturn(false)
//            when(mock.someReadyPeers()).thenReturn([peer])
//        }
//
//        do {
//            try peerGroup.sendPendingTransactions()
//            waitForMainQueue()
//            XCTFail("Should throw exception")
//        } catch let error as PeerGroup.PeerGroupError {
//            XCTAssertEqual(error, PeerGroup.PeerGroupError.peersNotSynced)
//        } catch {
//            XCTFail("Unexpected exception thrown")
//        }
//
//        verify(peer, never()).add(task: any())
//    }
//
//    func testSendPendingTransactions_NoReadyPeers() {
//        let transaction = TestData.p2pkTransaction
//        let peer = peers["0"]!
//
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([transaction])
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([peer])
//            when(mock.halfIsSynced()).thenReturn(true)
//            when(mock.someReadyPeers()).thenReturn([])
//        }
//
//        try! peerGroup.sendPendingTransactions()
//        waitForMainQueue()
//
//        verify(peer, never()).add(task: any())
//    }
//
//    func testCheckPeersSynced() {
//        let transaction = TestData.p2pkTransaction
//        let peer = peers["0"]!
//
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([transaction])
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([peer])
//            when(mock.halfIsSynced()).thenReturn(true)
//            when(mock.someReadyPeers()).thenReturn([peer])
//        }
//
//        try! peerGroup.checkPeersSynced()
//    }
//
//    func testCheckPeersSynced_NoConnectedPeers() {
//        let transaction = TestData.p2pkTransaction
//        let peer = peers["0"]!
//
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([transaction])
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([])
//            when(mock.halfIsSynced()).thenReturn(true)
//            when(mock.someReadyPeers()).thenReturn([peer])
//        }
//
//        do {
//            try peerGroup.checkPeersSynced()
//            waitForMainQueue()
//            XCTFail("Should throw exception")
//        } catch let error as PeerGroup.PeerGroupError {
//            XCTAssertEqual(error, PeerGroup.PeerGroupError.noConnectedPeers)
//        } catch {
//            XCTFail("Unexpected exception thrown")
//        }
//    }
//
//    func testCheckPeersSynced_PeersAreNotSynced() {
//        let transaction = TestData.p2pkTransaction
//        let peer = peers["0"]!
//
//        stub(mockTransactionSyncer) { mock in
//            when(mock.pendingTransactions()).thenReturn([transaction])
//        }
//        stub(mockPeerManager) { mock in
//            when(mock.connected()).thenReturn([peer])
//            when(mock.halfIsSynced()).thenReturn(false)
//            when(mock.someReadyPeers()).thenReturn([peer])
//        }
//
//        do {
//            try peerGroup.checkPeersSynced()
//            waitForMainQueue()
//            XCTFail("Should throw exception")
//        } catch let error as PeerGroup.PeerGroupError {
//            XCTAssertEqual(error, PeerGroup.PeerGroupError.peersNotSynced)
//        } catch {
//            XCTFail("Unexpected exception thrown")
//        }
//    }
//
//}
