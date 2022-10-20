import Quick
import Nimble
import XCTest
import Cuckoo
import RxSwift
@testable import BitcoinCore

class InitialSyncerTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockBlockDiscovery = MockIBlockDiscovery()
        let mockAddressManager = MockIPublicKeyManager()
        let mockDelegate = MockIInitialSyncerDelegate()

        var syncer: InitialSyncer!

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.add(blockHashes: any())).thenDoNothing()
            }
            stub(mockDelegate) { mock in
                when(mock.onSyncSuccess()).thenDoNothing()
                when(mock.onSyncFailed(error: any())).thenDoNothing()
            }

            syncer = InitialSyncer(
                    storage: mockStorage, blockDiscovery: mockBlockDiscovery,
                    publicKeyManager: mockAddressManager, async: false
            )

            syncer.delegate = mockDelegate
        }

        afterEach {
            reset(mockStorage, mockBlockDiscovery, mockAddressManager, mockDelegate)

            syncer = nil
        }

        describe("#sync") {
            context("when not synced yet") {
                let internalKeys = [PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data())]
                let externalKeys = [PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data())]
                let blockHash0 = BlockHash(headerHashReversedHex: "00", height: 0, sequence: 0)!
                let blockHash1 = BlockHash(headerHashReversedHex: "01", height: 1, sequence: 1)!
                let internalBlockHashes = [blockHash0, blockHash1]
                let externalBlockHashes = [blockHash1]

                context("when blockDiscovery fails to fetch block hashes") {
                    beforeEach {
                        stub(mockBlockDiscovery) { mock in
                            when(mock.discoverBlockHashes(account: 0)).thenReturn(Single.error(BitcoinCore.StateError.notStarted))
                        }

                        syncer.sync()
                    }

                    it("triggers #onSyncFailed on delegate") {
                        verify(mockDelegate).onSyncFailed(error: any())
                    }

                    it("discovers block hashes and used public keys from blockDiscovery for accounts 0") {
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 0)
                        verify(mockBlockDiscovery, never()).discoverBlockHashes(account: 1)
                    }
                }

                context("when blockDiscovery succeeds") {
                    beforeEach {
                        stub(mockAddressManager) { mock in
                            when(mock.addKeys(keys: any())).thenDoNothing()
                        }
                        stub(mockBlockDiscovery) { mock in
                            when(mock.discoverBlockHashes(account: 0)).thenReturn(Single.just((internalKeys + externalKeys, internalBlockHashes + externalBlockHashes)))
                            when(mock.discoverBlockHashes(account: 1)).thenReturn(Single.just(([], [])))
                        }

                        syncer.sync()
                    }

                    it("triggers #onSyncSuccess on delegate") {
                        verify(mockDelegate).onSyncSuccess()
                    }

                    it("discovers block hashes and used public keys from blockDiscovery accounts 0 and 1") {
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 0)
                        verify(mockBlockDiscovery).discoverBlockHashes(account: 1)
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
                }
            }
        }

        describe("#stop") {
        }
    }
}
