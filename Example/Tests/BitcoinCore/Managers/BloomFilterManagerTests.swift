import Quick
import Nimble
import XCTest
import Cuckoo
import HdWalletKit
@testable import BitcoinCore

class BloomFilterManagerTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockFactory = MockIFactory()
        let mockBloomFilterManagerDelegate = MockIBloomFilterManagerDelegate()
        let mockBloomFilterProvider = MockIBloomFilterProvider()

        let bloomFilter = BloomFilter(elements: [Data(from: 9999999)])
        let lastBlock = TestData.checkpointBlock

        var manager: BloomFilterManager!

        beforeEach {
            stub(mockBloomFilterManagerDelegate) { mock in
                when(mock.bloomFilterUpdated(bloomFilter: any())).thenDoNothing()
            }
            stub(mockFactory) { mock in
                when(mock).bloomFilter(withElements: any()).thenReturn(bloomFilter)
            }
            stub(mockStorage) { mock in
                when(mock.lastBlock.get).thenReturn(lastBlock)
            }

            manager = BloomFilterManager(factory: mockFactory)
            manager.delegate = mockBloomFilterManagerDelegate
        }

        afterEach {
            reset(mockStorage, mockFactory, mockBloomFilterManagerDelegate)

            manager = nil
        }

        describe("#regenerateBloomFilter") {
            context("when has providers") {
                let elements = [Data(repeating: 0, count: 32), Data(repeating: 1, count: 20)]

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.publicKeys()).thenReturn([])
                        when(mock.outputsWithPublicKeys()).thenReturn([])
                    }
                    stub(mockBloomFilterProvider) { mock in
                        when(mock.bloomFilterManager.set(_: any())).thenDoNothing()
                        when(mock.filterElements()).thenReturn(elements)
                    }

                    manager.add(provider: mockBloomFilterProvider)
                }

                afterEach {
                    reset(mockBloomFilterProvider)
                }

                it("adds elements to bloom filter") {
                    manager.regenerateBloomFilter()

                    verify(mockFactory).bloomFilter(withElements: equal(to: elements))
                    verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
                }
            }

            context("when no elements") {
                it("doesn't trigger events") {
                    stub(mockStorage) { mock in
                        when(mock.publicKeys()).thenReturn([])
                        when(mock.outputsWithPublicKeys()).thenReturn([])
                    }

                    manager.regenerateBloomFilter()
                    verify(mockFactory, never()).bloomFilter(withElements: any())
                    verify(mockBloomFilterManagerDelegate, never()).bloomFilterUpdated(bloomFilter: any())
                }
            }
        }
    }

}
