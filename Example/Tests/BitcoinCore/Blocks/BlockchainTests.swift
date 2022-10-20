import Quick
import Nimble
import XCTest
import Cuckoo
@testable import BitcoinCore

class BlockchainTest: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let mockBlockValidator = MockIBlockValidator()
        let mockFactory = MockIFactory()
        let mockBlockchainDataListener = MockIBlockchainDataListener()
        var blockchain: Blockchain!

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.unstaleAllBlocks()).thenDoNothing()
                when(mock.add(block: any())).thenDoNothing()
                when(mock.delete(blocks: any())).thenDoNothing()
            }

            stub(mockBlockchainDataListener) { mock in
                when(mock.onDelete(transactionHashes: any())).thenDoNothing()
                when(mock.onInsert(block: any())).thenDoNothing()
            }

            blockchain = Blockchain(storage: mockStorage, blockValidator: mockBlockValidator, factory: mockFactory, listener: mockBlockchainDataListener)
        }

        afterEach {
            reset(mockStorage, mockBlockValidator, mockFactory, mockBlockchainDataListener)
            blockchain = nil
        }

        describe("#connect") {
            context("when block exists") {
                let merkleBlock = MerkleBlock(header: TestData.checkpointBlock.header, transactionHashes: [Data](), transactions: [FullTransaction]())
                let block = Block(withHeader: TestData.checkpointBlock.header, height: 0)

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.block(byHash: equal(to: merkleBlock.headerHash))).thenReturn(block)
                    }
                }

                it("returns existing block") {
                    expect(try! blockchain.connect(merkleBlock: merkleBlock)).to(equal(block))
                }

                it("doesn't add a block to storage") {
                    verify(mockStorage, never()).add(block: any())
                    verifyNoMoreInteractions(mockBlockchainDataListener)
                    verifyNoMoreInteractions(mockStorage)
                }
            }

            context("when block doesn't exist") {
                let previousBlock = Block(withHeader: TestData.checkpointBlock.header, height: 0)
                let merkleBlock = MerkleBlock(header: TestData.firstBlock.header, transactionHashes: [Data](), transactions: [FullTransaction]())
                let newBlock = Block(withHeader: merkleBlock.header, previousBlock: previousBlock)

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.block(byHash: equal(to: merkleBlock.headerHash))).thenReturn(nil)
                    }
                }

                context("when block is not in chain") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.block(byHash: equal(to: merkleBlock.header.previousBlockHeaderHash))).thenReturn(nil)
                        }
                    }

                    it("throws BlockValidatorError.noPreviousBlock error") {
                        do {
                            _ = try blockchain.connect(merkleBlock: merkleBlock)
                            XCTFail("Should throw exception")
                        } catch let error as BitcoinCoreErrors.BlockValidation {
                            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.noPreviousBlock)
                        } catch {
                            XCTFail("Unexpected exception thrown")
                        }
                    }

                    it("doesn't add a block to storage") {
                        _ = try? blockchain.connect(merkleBlock: merkleBlock)
                        verify(mockStorage, never()).add(block: any())
                        verifyNoMoreInteractions(mockBlockchainDataListener)
                    }
                }

                context("when block is in chain") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.block(byHash: equal(to: merkleBlock.header.previousBlockHeaderHash))).thenReturn(previousBlock)
                        }
                        stub(mockFactory) { mock in
                            when(mock.block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: previousBlock))).thenReturn(newBlock)
                        }
                    }

                    context("when block is invalid") {
                        it("doesn't add a block to storage") {
                            stub(mockBlockValidator) { mock in
                                when(mock.validate(block: equal(to: newBlock), previousBlock: equal(to: previousBlock))).thenThrow(BitcoinCoreErrors.BlockValidation.wrongPreviousHeader)
                            }

                            do {
                                _ = try blockchain.connect(merkleBlock: merkleBlock)
                                XCTFail("Should throw exception")
                            } catch let error as BitcoinCoreErrors.BlockValidation {
                                XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.wrongPreviousHeader)
                            } catch {
                                XCTFail("Unexpected exception thrown")
                            }

                            verify(mockStorage, never()).add(block: any())
                            verifyNoMoreInteractions(mockBlockchainDataListener)
                        }
                    }

                    context("when block is valid") {
                        var connectedBlock: Block!

                        beforeEach {
                            stub(mockBlockValidator) { mock in
                                when(mock.validate(block: equal(to: newBlock), previousBlock: equal(to: previousBlock))).thenDoNothing()
                            }

                            connectedBlock = try! blockchain.connect(merkleBlock: merkleBlock)
                        }

                        it("adds block to database") {
                            verify(mockBlockValidator).validate(block: equal(to: newBlock), previousBlock: equal(to: previousBlock))
                            verify(mockFactory).block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: previousBlock))
                            verify(mockBlockchainDataListener).onInsert(block: equal(to: newBlock))
                            verify(mockStorage).add(block: equal(to: newBlock))
                        }

                        it("sets 'stale' true") {
                            XCTAssertEqual(connectedBlock.headerHash, newBlock.headerHash)
                            XCTAssertEqual(connectedBlock.stale, true)
                        }
                    }
                }
            }

        }

        describe("#forceAdd") {
            let merkleBlock = MerkleBlock(header: TestData.checkpointBlock.header, transactionHashes: [Data](), transactions: [FullTransaction]())
            let height = 1
            let block = Block(withHeader: TestData.checkpointBlock.header, height: height)

            context("when block exists") {
                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.block(byHash: equal(to: merkleBlock.headerHash))).thenReturn(block)
                    }
                }

                it("returns existing block") {
                    expect(try! blockchain.forceAdd(merkleBlock: merkleBlock, height: height)).to(equal(block))
                }

                it("doesn't add a block to storage") {
                    verify(mockStorage, never()).add(block: any())
                    verifyNoMoreInteractions(mockBlockchainDataListener)
                    verifyNoMoreInteractions(mockStorage)
                }
            }

            context("when block doesn't exist") {
                var connectedBlock: Block!

                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.block(byHash: equal(to: merkleBlock.headerHash))).thenReturn(nil)
                    }
                    stub(mockFactory) { mock in
                        when(mock.block(withHeader: equal(to: merkleBlock.header), height: equal(to: 1))).thenReturn(block)
                    }

                    connectedBlock = try! blockchain.forceAdd(merkleBlock: merkleBlock, height: height)
                }

                it("doesn't validate block") {
                    verify(mockBlockValidator, never()).validate(block: any(), previousBlock: any())
                }

                it("adds block to database") {
                    verify(mockFactory).block(withHeader: equal(to: merkleBlock.header), height: equal(to: height))
                    verify(mockBlockchainDataListener).onInsert(block: equal(to: block))
                    verify(mockStorage).add(block: equal(to: block))
                }

                it("sets 'stale' true") {
                    XCTAssertEqual(connectedBlock.headerHash, block.headerHash)
                    XCTAssertEqual(connectedBlock.stale, false)
                }
            }
        }

        describe("#handleFork") {
            var mockedBlocks: MockedBlocks!
            var inChainBlocksAfterFork: [Block]!
            var inChainBlocksAfterForkTransactionHexes: [Data]!

            context("when no fork found") {
                let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
                let newBlocks = [4: "11111114", 5: "11111115", 6: "11111116"]

                it("makes new blocks not stale") {
                    mockedBlocks = self.mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
                    try! blockchain.handleFork()

                    verify(mockStorage).unstaleAllBlocks()
                }
            }

            context("when fork found and new blocks leaf is longer") {
                let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
                let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

                beforeEach {
                    mockedBlocks = self.mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
                    inChainBlocksAfterFork = Array(mockedBlocks.blocksInChain.suffix(from: 1))
                    inChainBlocksAfterForkTransactionHexes = Array(mockedBlocks.blocksInChainTransactionHashes.suffix(from: 1))
                }

                it("deletes old blocks in chain after the fork") {
                    try! blockchain.handleFork()

                    verify(mockStorage).delete(blocks: equal(to: inChainBlocksAfterFork))
                    verify(mockStorage, never()).delete(blocks: equal(to: mockedBlocks.newBlocks))
                    verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: inChainBlocksAfterForkTransactionHexes.map { $0.reversedHex }))
                }

                it("makes new blocks not stale") {
                    try! blockchain.handleFork()

                    verify(mockStorage).unstaleAllBlocks()
                }
            }

            context("when fork found and new blocks leaf is shorter") {
                let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003", 4: "00000004"]
                let newBlocks = [2: "11111112", 3: "11111113"]

                it("deletes new blocks") {
                    mockedBlocks = self.mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
                    inChainBlocksAfterFork = Array(mockedBlocks.blocksInChain.suffix(from: 2))
                    try! blockchain.handleFork()

                    verify(mockStorage).delete(blocks: equal(to: mockedBlocks.newBlocks))
                    verify(mockStorage, never()).delete(blocks: equal(to: inChainBlocksAfterFork))
                    verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: mockedBlocks.newBlocksTransactionHashes.map { $0.reversedHex }))
                }
            }

            context("when fork exists and two leafs are equal") {
                let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
                let newBlocks = [2: "11111112", 3: "11111113"]

                it("deletes new blocks") {
                    mockedBlocks = self.mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
                    inChainBlocksAfterFork = Array(mockedBlocks.blocksInChain.suffix(from: 1))
                    try! blockchain.handleFork()

                    verify(mockStorage).delete(blocks: equal(to: mockedBlocks.newBlocks))
                    verify(mockStorage, never()).delete(blocks: equal(to: inChainBlocksAfterFork))
                    verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: mockedBlocks.newBlocksTransactionHashes.map { $0.reversedHex }))
                }
            }

            context("when no new(stale) blocks found") {
                let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
                let newBlocks = [Int: String]()

                it("doesn't do nothing") {
                    _ = self.mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
                    try! blockchain.handleFork()

                    verify(mockStorage, never()).delete(blocks: any())
                    verify(mockBlockchainDataListener, never()).onDelete(transactionHashes: any())
                }
            }

            context("when no blocks in chain") {
                let blocksInChain = [Int: String]()
                let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

                it("makes new blocks not stale") {
                    mockedBlocks = self.mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
                    try! blockchain.handleFork()

                    verify(mockStorage, never()).delete(blocks: any())
                    verify(mockStorage).unstaleAllBlocks()
                }
            }
        }

        describe("#deleteBlocks") {
            let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]
            var mockedBlocks: MockedBlocks!

            beforeEach {
                mockedBlocks = self.mockBlocks(blocksInChain: [Int: String](), newBlocks: newBlocks, mockStorage: mockStorage)
                try! blockchain.deleteBlocks(blocks: mockedBlocks.newBlocks)
            }

            it("deletes blocks") {
                verify(mockStorage).delete(blocks: equal(to: mockedBlocks.newBlocks))
            }

            it("notifies listener that transactions deleted") {
                verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: mockedBlocks.newBlocksTransactionHashes.map { $0.reversedHex }))
            }
        }
    }

    private func mockBlocks(blocksInChain: [Int: String], newBlocks: [Int: String], mockStorage: MockIStorage) -> MockedBlocks {
        var mockedBlocks = MockedBlocks()

        stub(mockStorage) { mock in
            for (height, id) in blocksInChain.sorted(by: { $0.key < $1.key }) {
                let block = Block(
                        withHeader: BlockHeader(version: 0, headerHash: Data(), previousBlockHeaderHash: Data(), merkleRoot: Data(), timestamp: height, bits: 0, nonce: 0),
                        height: height
                )
                block.setHeaderHash(hash: Data(from: id))
                block.stale = false
                mockedBlocks.blocksInChain.append(block)

                let transaction = TestData.p2pkTransaction
                transaction.header.dataHash = block.headerHash

                when(mock.transactions(ofBlock: equal(to: block))).thenReturn([transaction.header])
                mockedBlocks.blocksInChainTransactionHashes.append(transaction.header.dataHash)
            }

            for (height, id) in newBlocks.sorted(by: { $0.key < $1.key }) {
                let block = Block(
                        withHeader: BlockHeader(version: 0, headerHash: Data(), previousBlockHeaderHash: Data(), merkleRoot: Data(), timestamp: height, bits: 0, nonce: 0),
                        height: height
                )
                block.setHeaderHash(hash: Data(from: id))
                block.stale = true
                mockedBlocks.newBlocks.append(block)

                let transaction = TestData.p2pkTransaction
                transaction.header.dataHash = block.headerHash

                when(mock.transactions(ofBlock: equal(to: block))).thenReturn([transaction.header])
                mockedBlocks.newBlocksTransactionHashes.append(transaction.header.dataHash)
            }

            when(mock.blocks(stale: true)).thenReturn(mockedBlocks.newBlocks)

            if let firstStale = mockedBlocks.newBlocks.first {
                when(mock.block(stale: true, sortedHeight: equal(to: "ASC"))).thenReturn(firstStale)

                if let lastStale = mockedBlocks.newBlocks.last {
                    when(mock.block(stale: true, sortedHeight: "DESC")).thenReturn(lastStale)

                    let inChainBlocksAfterForkPoint = mockedBlocks.blocksInChain.filter { $0.height >= firstStale.height }
                    when(mock.blocks(heightGreaterThanOrEqualTo: firstStale.height, stale: false)).thenReturn(inChainBlocksAfterForkPoint)
                }
            } else {
                when(mock.block(stale: true, sortedHeight: equal(to: "ASC"))).thenReturn(nil)
            }

            if let lastNotStale = mockedBlocks.blocksInChain.last {
                when(mock.block(stale: false, sortedHeight: "DESC")).thenReturn(lastNotStale)
            } else {
                when(mock.block(stale: false, sortedHeight: "DESC")).thenReturn(nil)
            }
        }

        return mockedBlocks
    }

    struct MockedBlocks {
        var newBlocks = [Block]()
        var blocksInChain = [Block]()
        var newBlocksTransactionHashes = [Data]()
        var blocksInChainTransactionHashes = [Data]()
    }

}
