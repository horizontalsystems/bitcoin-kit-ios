import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class BlockSyncerTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockFactory = MockIFactory()
        let mockListener = MockIBlockSyncListener()
        let mockTransactionProcessor = MockIBlockTransactionProcessor()
        let mockBlockchain = MockIBlockchain()
        let mockAddressManager = MockIPublicKeyManager()
        let mockState = MockBlockSyncerState()

        let checkpoint = TestData.checkpoint
        var syncer: BlockSyncer!

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.blocksCount.get).thenReturn(1)
                when(mock.lastBlock.get).thenReturn(nil)
                when(mock.deleteBlockchainBlockHashes()).thenDoNothing()
            }
            stub(mockBlockchain) { mock in
                when(mock.handleFork()).thenDoNothing()
            }
            stub(mockAddressManager) { mock in
                when(mock.fillGap()).thenDoNothing()
            }
            stub(mockState) { mock in
                when(mock.iteration(hasPartialBlocks: any())).thenDoNothing()
            }
        }

        afterEach {
            reset(mockStorage, mockListener, mockTransactionProcessor, mockBlockchain, mockAddressManager, mockState)

            syncer = nil
        }

        context("static methods") {
            describe("#resolveCheckpoint") {
                let bip44Checkpoint = TestData.checkpoint
                let lastCheckpoint = TestData.lastCheckpoint
                let mockNetwork = MockINetwork()

                beforeEach {
                    stub(mockNetwork) { mock in
                        when(mock.bip44Checkpoint.get).thenReturn(bip44Checkpoint)
                        when(mock.lastCheckpoint.get).thenReturn(lastCheckpoint)
                    }
                }

                afterEach {
                    reset(mockNetwork)
                }

                context("when there are some blocks in storage") {
                    let lastBlock = TestData.secondBlock

                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.lastBlock.get).thenReturn(lastBlock)
                        }
                    }

                    it("doesn't save checkpointBlock to storage") {
                        _ = BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .api, storage: mockStorage)

                        verify(mockStorage, never()).save(block: any())
                        verify(mockStorage).lastBlock.get()
                        verifyNoMoreInteractions(mockStorage)
                    }

                    context("when syncMode is .full") {
                        it("returns bip44CheckpointBlock") {
                            expect(BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .full, storage: mockStorage)).to(equal(bip44Checkpoint))
                        }
                    }

                    context("when syncMode is not .full") {
                        context("when lastBlock's height is more than lastCheckpointBlock") {
                            it("returns lastCheckpointBlock") {
                                lastBlock.height = lastCheckpoint.block.height + 1
                                expect(BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .api, storage: mockStorage)).to(equal(lastCheckpoint))
                            }
                        }

                        context("when lastBlock's height is less than lastCheckpointBlock") {
                            it("returns bip44CheckpointBlock") {
                                lastBlock.height = lastCheckpoint.block.height - 1
                                expect(BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .api, storage: mockStorage)).to(equal(bip44Checkpoint))
                            }
                        }
                    }
                }

                context("when there's no block in storage") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.lastBlock.get).thenReturn(nil)
                            when(mock.save(block: any())).thenDoNothing()
                        }
                    }

                    context("when syncMode is .full") {
                        it("returns bip44Checkpoint") {
                            expect(BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .full, storage: mockStorage)).to(equal(bip44Checkpoint))
                        }

                        it("saves bip44Checkpoint to storage") {
                            _ = BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .full, storage: mockStorage)
                            verify(mockStorage).save(block: sameInstance(as: bip44Checkpoint.block))
                        }
                    }

                    context("when syncMode is not .full") {
                        it("returns lastCheckpoint") {
                            expect(BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .api, storage: mockStorage)).to(equal(lastCheckpoint))
                        }

                        it("saves lastCheckpoint to storage") {
                            _ = BlockSyncer.resolveCheckpoint(network: mockNetwork, syncMode: .api, storage: mockStorage)
                            verify(mockStorage).save(block: sameInstance(as: lastCheckpoint.block))
                        }
                    }
                }
            }
        }

        context("instance methods") {
            beforeEach {
                syncer = BlockSyncer(storage: mockStorage, checkpoint: checkpoint, factory: mockFactory, transactionProcessor: mockTransactionProcessor,
                        blockchain: mockBlockchain, publicKeyManager: mockAddressManager,
                        hashCheckpointThreshold: 100, logger: nil, state: mockState)

                syncer.listener = mockListener
            }

            describe("#localDownloadedBestBlockHeight") {
                context("when there are some blocks in storage") {
                    it("returns the height of the last block") {
                        stub(mockStorage) { mock in
                            when(mock.lastBlock.get).thenReturn(checkpoint.block)
                        }
                        expect(syncer.localDownloadedBestBlockHeight).to(equal(Int32(checkpoint.block.height)))
                    }
                }

                context("when there's no block in storage") {
                    it("returns 0") {
                        stub(mockStorage) { mock in
                            when(mock.lastBlock.get).thenReturn(nil)
                        }
                        expect(syncer.localDownloadedBestBlockHeight).to(equal(0))
                    }
                }
            }

            describe("#localKnownBestBlockHeight") {
                let blockHash = BlockHash(headerHash: Data(repeating: 0, count: 32), height: 0, order: 0)

                context("when no blockHashes") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.blockchainBlockHashes.get).thenReturn([])
                            when(mock.blocksCount(headerHashes: equal(to: []))).thenReturn(0)
                        }
                    }

                    context("when no blocks") {
                        it("returns 0") {
                            expect(syncer.localKnownBestBlockHeight).to(equal(0))
                        }
                    }

                    context("when there are some blocks") {
                        it("returns last block's height + blocks count") {
                            stub(mockStorage) { mock in
                                when(mock.lastBlock.get).thenReturn(checkpoint.block)
                            }
                            expect(syncer.localKnownBestBlockHeight).to(equal(Int32(checkpoint.block.height)))
                        }
                    }
                }

                context("when there are some blockHashes which haven't downloaded blocks") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.blockchainBlockHashes.get).thenReturn([blockHash])
                            when(mock.blocksCount(headerHashes: equal(to: [blockHash.headerHash]))).thenReturn(0)
                        }
                    }

                    it("returns lastBlock + blockHashes count") {
                        expect(syncer.localKnownBestBlockHeight).to(equal(1))
                        stub(mockStorage) { mock in
                            when(mock.lastBlock.get).thenReturn(checkpoint.block)
                        }
                        expect(syncer.localKnownBestBlockHeight).to(equal(Int32(checkpoint.block.height + 1)))
                    }
                }

                context("when there are some blockHashes which have downloaded blocks") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.blockchainBlockHashes.get).thenReturn([blockHash])
                            when(mock.blocksCount(headerHashes: equal(to: [blockHash.headerHash]))).thenReturn(1)
                        }
                    }

                    it("returns lastBlock + count of blockHashes without downloaded blocks") {
                        expect(syncer.localKnownBestBlockHeight).to(equal(0))
                        stub(mockStorage) { mock in
                            when(mock.lastBlock.get).thenReturn(checkpoint.block)
                        }
                        expect(syncer.localKnownBestBlockHeight).to(equal(Int32(checkpoint.block.height)))
                    }
                }
            }

            describe("#prepareForDownload") {
                let emptyBlocks = [Block]()

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.blockHashHeaderHashes(except: equal(to: [checkpoint.block.headerHash]))).thenReturn([])
                        when(mock.blocks(byHexes: equal(to: []))).thenReturn(emptyBlocks)
                    }
                    stub(mockBlockchain) { mock in
                        when(mock.deleteBlocks(blocks: equal(to: emptyBlocks))).thenDoNothing()
                    }

                    syncer.prepareForDownload()
                }

                it("handles partial blocks") {
                    verify(mockAddressManager).fillGap()
                    verify(mockState).iteration(hasPartialBlocks: equal(to: false))
                }

                it("clears BlockHashes") {
                    verify(mockStorage).deleteBlockchainBlockHashes()
                }

                it("clears partialBlock blocks") {
                    verify(mockStorage).blockHashHeaderHashes(except: equal(to: [checkpoint.block.headerHash]))
                    verify(mockStorage).blocks(byHexes: equal(to: []))
                    verify(mockBlockchain).deleteBlocks(blocks: equal(to: emptyBlocks))
                }

                it("handles fork") {
                    verify(mockBlockchain).handleFork()
                }
            }

            describe("#downloadIterationCompleted") {
                context("when iteration has partial blocks") {
                    it("handles partial blocks") {
                        stub(mockState) { mock in
                            when(mock.iterationHasPartialBlocks.get).thenReturn(true)
                        }
                        syncer.downloadIterationCompleted()

                        verify(mockAddressManager).fillGap()
                        verify(mockState).iteration(hasPartialBlocks: equal(to: false))
                    }
                }

                context("when iteration has not partial blocks") {
                    it("does not handle partial blocks") {
                        stub(mockState) { mock in
                            when(mock.iterationHasPartialBlocks.get).thenReturn(false)
                        }
                        syncer.downloadIterationCompleted()

                        verify(mockAddressManager, never()).fillGap()
                        verify(mockState, never()).iteration(hasPartialBlocks: any())
                    }
                }
            }

            describe("#downloadCompleted") {
                it("handles fork") {
                    syncer.downloadCompleted()
                    verify(mockBlockchain).handleFork()
                }
            }

            describe("#downloadFailed") {
                let emptyBlocks = [Block]()

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.blockHashHeaderHashes(except: equal(to: [checkpoint.block.headerHash]))).thenReturn([])
                        when(mock.blocks(byHexes: equal(to: []))).thenReturn(emptyBlocks)
                    }
                    stub(mockBlockchain) { mock in
                        when(mock.deleteBlocks(blocks: equal(to: emptyBlocks))).thenDoNothing()
                    }

                    syncer.downloadFailed()
                }

                it("handles partial blocks") {
                    verify(mockAddressManager).fillGap()
                    verify(mockState).iteration(hasPartialBlocks: equal(to: false))
                }

                it("clears BlockHashes") {
                    verify(mockStorage).deleteBlockchainBlockHashes()
                }

                it("clears partialBlock blocks") {
                    verify(mockStorage).blockHashHeaderHashes(except: equal(to: [checkpoint.block.headerHash]))
                    verify(mockStorage).blocks(byHexes: equal(to: []))
                    verify(mockBlockchain).deleteBlocks(blocks: equal(to: emptyBlocks))
                }

                it("handles fork") {
                    verify(mockBlockchain).handleFork()
                }
            }

            describe("#getBlockHashes") {
                it("returns first 500 blockhashes") {
                    let blockHashes = [BlockHash(headerHash: Data(repeating: 0, count: 0), height: 0, order: 0)]
                    stub(mockStorage) { mock in
                        when(mock.blockHashesSortedBySequenceAndHeight(limit: equal(to: 500))).thenReturn(blockHashes)
                    }

                    expect(syncer.getBlockHashes()).to(equal(blockHashes))
                    verify(mockStorage).blockHashesSortedBySequenceAndHeight(limit: equal(to: 500))
                }
            }

            describe("#getBlockLocatorHashes(peerLastBlockHeight:)") {
                let peerLastBlockHeight: Int32 = 10
                let firstBlock = TestData.firstBlock
                let secondBlock = TestData.secondBlock

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.lastBlockchainBlockHash.get).thenReturn(nil)
                        when(mock.blocks(heightGreaterThan: equal(to: checkpoint.block.height), sortedBy: equal(to: Block.Columns.height), limit: equal(to: 10))).thenReturn([Block]())
                        when(mock.block(byHeight: Int(peerLastBlockHeight))).thenReturn(nil)
                    }
                }

                context("when there's no blocks or blockhashes") {
                    it("returns checkpointBlock's header hash") {
                        expect(syncer.getBlockLocatorHashes(peerLastBlockHeight: peerLastBlockHeight)).to(equal([checkpoint.block.headerHash]))
                    }
                }

                context("when there are blockchain blockhashes") {
                    it("returns last blockchain blockhash") {
                        let blockHash = BlockHash(headerHash: Data(repeating: 0, count: 0), height: 0, order: 0)
                        stub(mockStorage) { mock in
                            when(mock.lastBlockchainBlockHash.get).thenReturn(blockHash)
                            when(mock.blocks(heightGreaterThan: equal(to: checkpoint.block.height), sortedBy: equal(to: Block.Columns.height), limit: equal(to: 10))).thenReturn([firstBlock, secondBlock])
                        }

                        expect(syncer.getBlockLocatorHashes(peerLastBlockHeight: peerLastBlockHeight)).to(equal([
                            blockHash.headerHash, checkpoint.block.headerHash
                        ]))
                    }
                }

                context("when there's no blockhashes but there are blocks") {
                    it("returns last 10 blocks' header hashes") {
                        stub(mockStorage) { mock in
                            when(mock.blocks(heightGreaterThan: equal(to: checkpoint.block.height), sortedBy: equal(to: Block.Columns.height), limit: equal(to: 10))).thenReturn([secondBlock, firstBlock])
                        }

                        expect(syncer.getBlockLocatorHashes(peerLastBlockHeight: peerLastBlockHeight)).to(equal([
                            secondBlock.headerHash, firstBlock.headerHash, checkpoint.block.headerHash
                        ]))
                    }
                }

                context("when the peers last block is already in storage") {
                    it("returns peers last block's headerHash instead of checkpointBlocks'") {
                        stub(mockStorage) { mock in
                            when(mock.block(byHeight: Int(peerLastBlockHeight))).thenReturn(firstBlock)
                        }

                        expect(syncer.getBlockLocatorHashes(peerLastBlockHeight: peerLastBlockHeight)).to(equal([firstBlock.headerHash]))
                    }
                }
            }

            describe("#add(blockHashes:)") {
                let existingBlockHash = Data(repeating: 0, count: 32)
                let newBlockHash = Data(repeating: 1, count: 32)
                let blockHash = BlockHash(headerHash: existingBlockHash, height: 0, order: 10)

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.blockHashHeaderHashes.get).thenReturn([existingBlockHash])
                        when(mock.add(blockHashes: any())).thenDoNothing()
                    }
                    stub(mockFactory) { mock in
                        when(mock.blockHash(withHeaderHash: equal(to: newBlockHash), height: equal(to: 0), order: any())).thenReturn(blockHash)
                    }
                }

                context("when there's a blockHash in storage") {
                    it("sets order of given blockhashes starting from last blockhashes order") {
                        let lastBlockHash = BlockHash(headerHash: Data(repeating: 0, count: 0), height: 0, order: 10)
                        stub(mockStorage) { mock in
                            when(mock.lastBlockHash.get).thenReturn(lastBlockHash)
                        }

                        syncer.add(blockHashes: [existingBlockHash, newBlockHash])

                        verify(mockFactory).blockHash(withHeaderHash: equal(to: newBlockHash), height: equal(to: 0), order: equal(to: lastBlockHash.sequence + 1))
                        verify(mockStorage).add(blockHashes: equal(to: [blockHash]))
                    }
                }

                context("when there's no blockhashes") {
                    it("sets order of given blockhashes starting from 0") {
                        stub(mockStorage) { mock in
                            when(mock.lastBlockHash.get).thenReturn(nil)
                        }

                        syncer.add(blockHashes: [existingBlockHash, newBlockHash])

                        verify(mockFactory).blockHash(withHeaderHash: equal(to: newBlockHash), height: equal(to: 0), order: equal(to: 1))
                        verify(mockStorage).add(blockHashes: equal(to: [blockHash]))
                    }
                }
            }

            describe("#handle(merkleBlock:,maxBlockHeight:)") {
                let block = TestData.firstBlock
                let merkleBlock = MerkleBlock(header: block.header, transactionHashes: [], transactions: [])
                let maxBlockHeight: Int32 = Int32(block.height + 100)

                beforeEach {
                    stub(mockBlockchain) { mock in
                        when(mock.forceAdd(merkleBlock: equal(to: merkleBlock), height: equal(to: block.height))).thenReturn(block)
                        when(mock.connect(merkleBlock: equal(to: merkleBlock))).thenReturn(block)
                    }
                    stub(mockTransactionProcessor) { mock in
                        when(mock.processReceived(transactions: any(), inBlock: any(), skipCheckBloomFilter: any())).thenDoNothing()
                    }
                    stub(mockState) { mock in
                        when(mock.iterationHasPartialBlocks.get).thenReturn(false)
                    }
                    stub(mockStorage) { mock in
                        when(mock.deleteBlockHash(byHash: equal(to: block.headerHash))).thenDoNothing()
                    }
                    stub(mockListener) { mock in
                        when(mock.currentBestBlockHeightUpdated(height: equal(to: Int32(block.height)), maxBlockHeight: equal(to: maxBlockHeight))).thenDoNothing()
                    }
                }

                it("handles merkleBlock") {
                    try! syncer.handle(merkleBlock: merkleBlock, maxBlockHeight: maxBlockHeight)

                    verify(mockBlockchain).connect(merkleBlock: equal(to: merkleBlock))
                    verify(mockTransactionProcessor).processReceived(transactions: equal(to: [FullTransaction]()), inBlock: equal(to: block), skipCheckBloomFilter: equal(to: false))
                    verify(mockStorage).deleteBlockHash(byHash: equal(to: block.headerHash))
                    verify(mockListener).currentBestBlockHeightUpdated(height: equal(to: Int32(block.height)), maxBlockHeight: equal(to: maxBlockHeight))
                }

                context("when merklBlocks's height is null") {
                    it("force adds the block to blockchain") {
                        merkleBlock.height = block.height
                        try! syncer.handle(merkleBlock: merkleBlock, maxBlockHeight: maxBlockHeight)

                        verify(mockBlockchain).forceAdd(merkleBlock: equal(to: merkleBlock), height: equal(to: block.height))
                        verifyNoMoreInteractions(mockBlockchain)
                    }
                }

                context("when bloom filter is expired while processing transactions") {
                    it("sets iteration state to hasPartialBlocks") {
                        stub(mockTransactionProcessor) { mock in
                            when(mock.processReceived(transactions: equal(to: [FullTransaction]()), inBlock: equal(to: block), skipCheckBloomFilter: equal(to: false))).thenThrow(BloomFilterManager.BloomFilterExpired())
                        }
                        try! syncer.handle(merkleBlock: merkleBlock, maxBlockHeight: maxBlockHeight)

                        verify(mockState).iteration(hasPartialBlocks: equal(to: true))
                    }
                }

                context("when iteration has partial blocks") {
                    it("doesn't delete block hash") {
                        stub(mockState) { mock in
                            when(mock.iterationHasPartialBlocks.get).thenReturn(true)
                        }
                        stub(mockTransactionProcessor) { mock in
                            when(mock.processReceived(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: equal(to: true))).thenDoNothing()
                        }
                        try! syncer.handle(merkleBlock: merkleBlock, maxBlockHeight: maxBlockHeight)

                        verify(mockStorage, never()).deleteBlockHash(byHash: equal(to: block.headerHash))
                    }
                }
            }

            describe("#shouldRequestBlock(withHash:)") {
                let hash = Data(repeating: 0, count: 32)

                context("when the given block is in storage") {
                    it("returns false") {
                        stub(mockStorage) { mock in
                            when(mock.block(byHash: equal(to: hash))).thenReturn(TestData.firstBlock)
                        }

                        expect(syncer.shouldRequestBlock(withHash: hash)).to(beFalsy())
                    }
                }

                context("when the given block is not in storage") {
                    it("returns true") {
                        stub(mockStorage) { mock in
                            when(mock.block(byHash: equal(to: hash))).thenReturn(nil)
                        }

                        expect(syncer.shouldRequestBlock(withHash: hash)).to(beTruthy())
                    }
                }
            }
        }
    }
}
