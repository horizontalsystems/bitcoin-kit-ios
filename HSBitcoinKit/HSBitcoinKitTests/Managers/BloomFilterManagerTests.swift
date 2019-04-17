import Quick
import Nimble
import XCTest
import Cuckoo
import HSHDWalletKit
@testable import HSBitcoinKit

class BloomFilterManagerTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockFactory = MockIFactory()
        let mockBloomFilterManagerDelegate = MockIBloomFilterManagerDelegate()

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

            manager = BloomFilterManager(storage: mockStorage, factory: mockFactory)
            manager.delegate = mockBloomFilterManagerDelegate
        }

        afterEach {
            reset(mockStorage, mockFactory, mockBloomFilterManagerDelegate)

            manager = nil
        }

        describe("#regenerateBloomFilter") {
            context("when has publicKeys") {
                let keys = [
                    getPublicKey(withIndex: 0, chain: .external),
                    getPublicKey(withIndex: 0, chain: .internal),
                    getPublicKey(withIndex: 1, chain: .external),
                ]

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.publicKeys()).thenReturn(keys)
                        when(mock.outputsWithPublicKeys()).thenReturn([])
                    }
                }

                it("adds keys to bloom filter") {
                    manager.regenerateBloomFilter()

                    var expectedElements: [Data] = []
                    for key in keys {
                        expectedElements.append(key.keyHash)
                        expectedElements.append(key.raw)
                        expectedElements.append(key.scriptHashForP2WPKH)
                    }

                    verify(mockFactory).bloomFilter(withElements: equal(to: expectedElements))
                    verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
                }
            }

            context("when has outputs with publicKeys") {
                let output1 = TestData.p2wpkhTransaction.outputs[0]
                output1.transactionHashReversedHex = Data(repeating: 0, count: 32).reversedHex

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.publicKeys()).thenReturn([])
                    }
                }

                context("when output is not spent") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: nil, spendingBlockHeight: nil)])
                        }
                    }

                    it("adds outputs to bloom filter") {
                        manager.regenerateBloomFilter()

                        let expectedElements = [output1.transactionHashReversedHex.reversedData! + self.byteArrayLittleEndian(int: output1.index)]

                        verify(mockFactory).bloomFilter(withElements: equal(to: expectedElements))
                        verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
                    }
                }

                context("when output is spent") {
                    let input = TestData.p2pkhTransaction.inputs[0]
                    input.previousOutputTxReversedHex = output1.transactionHashReversedHex
                    input.previousOutputIndex = output1.index

                    context("when spending transaction is in mempool") {
                        beforeEach {
                            stub(mockStorage) { mock in
                                when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: input, spendingBlockHeight: nil)])
                            }
                        }

                        it("adds output to bloom filter") {
                            manager.regenerateBloomFilter()

                            let expectedElements = [output1.transactionHashReversedHex.reversedData! + self.byteArrayLittleEndian(int: output1.index)]

                            verify(mockFactory).bloomFilter(withElements: equal(to: expectedElements))
                            verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
                        }
                    }

                    context("when spending transaction is in block") {
                        context("when block is not far enough in history") {
                            beforeEach {
                                stub(mockStorage) { mock in
                                    when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: input, spendingBlockHeight: lastBlock.height - 98)])
                                }
                            }

                            it("adds output to bloom filter") {
                                manager.regenerateBloomFilter()

                                let expectedElements = [output1.transactionHashReversedHex.reversedData! + self.byteArrayLittleEndian(int: output1.index)]

                                verify(mockFactory).bloomFilter(withElements: equal(to: expectedElements))
                                verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
                            }
                        }

                        context("when block is far enough") {
                            beforeEach {
                                stub(mockStorage) { mock in
                                    when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: input, spendingBlockHeight: lastBlock.height - 100)])
                                }
                            }

                            it("doesn't add output to bloom filter") {
                                manager.regenerateBloomFilter()

                                verify(mockFactory, never()).bloomFilter(withElements: any())
                                verify(mockBloomFilterManagerDelegate, never()).bloomFilterUpdated(bloomFilter: any())
                            }
                        }
                    }
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

            context("when no new element") {
                it("doesn't trigger events") {
                    stub(mockStorage) { mock in
                        when(mock.publicKeys()).thenReturn([self.getPublicKey(withIndex: 0, chain: .external)])
                        when(mock.outputsWithPublicKeys()).thenReturn([])
                    }

                    manager.regenerateBloomFilter()
                    verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: any())
                    reset(mockBloomFilterManagerDelegate)
                    stub(mockBloomFilterManagerDelegate) { mock in
                        when(mock.bloomFilterUpdated(bloomFilter: any())).thenDoNothing()
                    }

                    manager.regenerateBloomFilter()
                    verify(mockBloomFilterManagerDelegate, never()).bloomFilterUpdated(bloomFilter: any())
                }
            }
        }
    }

    private func getPublicKey(withIndex index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        let hdPrivKeyData = try! hdWallet.privateKeyData(account: 0, index: index, external: chain == .external)
        return PublicKey(withAccount: 0, index: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }

    private func byteArrayLittleEndian(int: Int) -> [UInt8] {
        return [
            UInt8(int & 0x000000FF),
            UInt8((int & 0x0000FF00) >> 8),
            UInt8((int & 0x00FF0000) >> 16),
            UInt8((int & 0xFF000000) >> 24)
        ]
    }

}
