import Quick
import Nimble
import XCTest
import Cuckoo
import RealmSwift
import RxSwift
@testable import HSBitcoinKit

class InitialSyncerTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockListener = MockISyncStateListener()
        let mockStateManager = MockIStateManager()
        let mockBlockDiscovery = MockIBlockDiscovery()
        let mockAddressManager = MockIAddressManager()
        let mockDelegate = MockIInitialSyncerDelegate()

        var syncer: InitialSyncer!

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.add(blockHashes: any())).thenDoNothing()
            }
            stub(mockListener) { mock in
                when(mock.syncStarted()).thenDoNothing()
                when(mock.syncStopped()).thenDoNothing()
            }
            stub(mockDelegate) { mock in
                when(mock.syncingFinished()).thenDoNothing()
            }

            syncer = InitialSyncer(
                    storage: mockStorage, listener: mockListener, stateManager: mockStateManager, blockDiscovery: mockBlockDiscovery,
                    addressManager: mockAddressManager, async: false
            )

            syncer.delegate = mockDelegate
        }

        afterEach {
            reset(mockStorage, mockListener, mockStateManager, mockBlockDiscovery, mockAddressManager, mockDelegate)

            syncer = nil
        }

        describe("#sync") {
            context("when already synced") {
                beforeEach {
                    stub(mockStateManager) { mock in
                        when(mock.restored.get).thenReturn(true)
                    }

                    syncer.sync()
                }

                it("triggers #syncingFinished on delegate") {
                    verify(mockDelegate).syncingFinished()
                }

                it("doesn't trigger #syncStarted on listener") {
                    verify(mockListener, never()).syncStarted()
                }
            }

            context("when not synced yet") {
                let internalKeys = [PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data())]
                let externalKeys = [PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data())]
                let blockHash0 = BlockHash(reversedHeaderHashHex: "00", height: 0, order: 0)!
                let blockHash1 = BlockHash(reversedHeaderHashHex: "01", height: 1, order: 1)!
                let internalBlockHashes = [blockHash0, blockHash1]
                let externalBlockHashes = [blockHash1]

                beforeEach {
                    stub(mockStateManager) { mock in
                        when(mock.restored.get).thenReturn(false)
                    }
                }

                context("when blockDiscovery fails to fetch block hashes") {
                    beforeEach {
                        stub(mockBlockDiscovery) { mock in
                            when(mock.discoverBlockHashes(account: 0, external: true)).thenReturn(Observable.error(ApiError.noConnection))
                            when(mock.discoverBlockHashes(account: 0, external: false)).thenReturn(Observable.just((externalKeys, externalBlockHashes)))
                        }

                        syncer.sync()
                    }

                    it("triggers #syncStopped on listener") {
                        verify(mockListener).syncStarted()
                        verify(mockListener).syncStopped()
                    }

                    it("discovers block hashes and used public keys from blockDiscovery for accounts 0") {
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 0, external: true)
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 0, external: false)

                        verify(mockBlockDiscovery, never()).discoverBlockHashes(account: 1, external: true)
                        verify(mockBlockDiscovery, never()).discoverBlockHashes(account: 1, external: false)
                    }
                }

                context("when blockDiscovery succeeds") {
                    beforeEach {
                        stub(mockStateManager) { mock in
                            when(mock.restored.set(any())).thenDoNothing()
                        }
                        stub(mockAddressManager) { mock in
                            when(mock.addKeys(keys: any())).thenDoNothing()
                        }
                        stub(mockBlockDiscovery) { mock in
                            when(mock.discoverBlockHashes(account: 0, external: true)).thenReturn(Observable.just((internalKeys, internalBlockHashes)))
                            when(mock.discoverBlockHashes(account: 0, external: false)).thenReturn(Observable.just((externalKeys, externalBlockHashes)))
                            when(mock.discoverBlockHashes(account: 1, external: true)).thenReturn(Observable.just(([], [])))
                            when(mock.discoverBlockHashes(account: 1, external: false)).thenReturn(Observable.just(([], [])))
                        }

                        syncer.sync()
                    }

                    it("triggers #syncStarted on listener") {
                        verify(mockListener).syncStarted()
                        verifyNoMoreInteractions(mockListener)
                    }

                    it("discovers block hashes and used public keys from blockDiscovery accounts 0 and 1") {
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 0, external: true)
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 0, external: false)

                        verify(mockBlockDiscovery).discoverBlockHashes(account: 1, external: true)
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 1, external: false)
                    }

                    it("adds discovered used public keys to addressManager") {
                        verify(mockAddressManager).addKeys(keys: equal(to: internalKeys + externalKeys))
                        verify(mockAddressManager).addKeys(keys: equal(to: []))
                        verifyNoMoreInteractions(mockAddressManager)
                    }

                    it("saves discovered unique block hashes in storage") {
                        verify(mockStorage).add(blockHashes: equal(to: [blockHash0, blockHash1]))
                        verifyNoMoreInteractions(mockStorage)
                    }

                    it("triggers #syncingFinished on delegate and set restored state") {
                        verify(mockDelegate).syncingFinished()
                        verify(mockStateManager).restored.set(true)
                    }
                }
            }
        }

        describe("#stop") {
        }
    }
}
