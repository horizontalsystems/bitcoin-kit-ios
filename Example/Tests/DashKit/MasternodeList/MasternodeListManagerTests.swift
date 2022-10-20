//import Foundation
//import XCTest
//import Quick
//import Nimble
//import Cuckoo
//@testable import BitcoinCore
//
//class MasternodeListManagerTests: QuickSpec {
//
//    override func spec() {
//        let mockStorage = MockIDashStorage()
//        let mockMasternodeListMerkleRootCalculator = MockIMasternodeListMerkleRootCalculator()
//        let mockMasternodeCbTxHasher = MockIMasternodeCbTxHasher()
//        let mockMerkleBranch = MockIMerkleBranch()
//        let mockMasternodeSortedList = MockIMasternodeSortedList()
//
//        var manager: MasternodeListManager!
//
//        beforeEach {
//            stub(mockMasternodeSortedList) { mock in
//                when(mock.removeAll()).thenDoNothing()
//                when(mock.remove(by: any())).thenDoNothing()
//                when(mock.add(masternodes: any())).thenDoNothing()
//            }
//
//            manager = MasternodeListManager(storage: mockStorage, masternodeListMerkleRootCalculator: mockMasternodeListMerkleRootCalculator, masternodeCbTxHasher: mockMasternodeCbTxHasher, merkleBranch: mockMerkleBranch, masternodeSortedList: mockMasternodeSortedList)
//        }
//
//        afterEach {
//            reset(mockStorage, mockMerkleBranch, mockMasternodeCbTxHasher, mockMasternodeSortedList, mockMasternodeListMerkleRootCalculator)
//
//            manager = nil
//        }
//
//        describe("#base_block_hash") {
//
//            it("gets nil block state") {
//                stub(mockStorage) { mock in
//                    when(mock.masternodeListState.get).thenReturn(nil)
//                }
//                expect(manager.baseBlockHash).to(equal(DashTestData.zeroHash))
//            }
//
//            it("gets not nil block state") {
//                let blockHash = Data(repeating: 1, count: 32)
//
//                stub(mockStorage) { mock in
//                    when(mock.masternodeListState.get).thenReturn(MasternodeListState(baseBlockHash: blockHash))
//                }
//
//                expect(manager.baseBlockHash).to(equal(blockHash))
//            }
//        }
//
//        describe("#update_list") {
//            let willDeleteProRegTxHash = Data(repeating: 2, count: 2)
//            let willAddedProRegTxHash1 = Data(repeating: 1, count: 2)
//            let willAddedProRegTxHash2 = Data(repeating: 3, count: 2)
//
//            let storageMasternodes = [
//                DashTestData.masternode(proRegTxHash: Data(repeating: 0, count: 2)),
//                DashTestData.masternode(proRegTxHash: Data(repeating: 1, count: 2)),
//                DashTestData.masternode(proRegTxHash: willDeleteProRegTxHash),
//            ]
//            let calculatedHash = Data(repeating: 5, count: 4)
//
//            let mnList = [DashTestData.masternode(proRegTxHash: willAddedProRegTxHash1, isValid: false), DashTestData.masternode(proRegTxHash: willAddedProRegTxHash2)]
//
//            let coinbaseTransaction = DashTestData.coinbaseTransaction(merkleRootMNList: calculatedHash)
//
//            let blockHash = Data(repeating: 1, count: 4)
//            let correctMerkleRoot = Data(repeating: 7, count: 32)
//            let block = Block(withHeader: BlockHeader(version: 0, headerHash: Data(), previousBlockHeaderHash: Data(),
//                              merkleRoot: correctMerkleRoot, timestamp: 0, bits: 0, nonce: 0)
//                        , height: 0)
//
//            let message = DashTestData.masternodeListDiffMessage(blockHash: blockHash, cbTx: coinbaseTransaction, deletedMNs: [willDeleteProRegTxHash], mnList: mnList)
//
//            let resultMasternodes = [storageMasternodes[0], mnList[0], mnList[1]]
//
//            beforeEach {
//                stub(mockStorage) { mock in
//                    when(mock.masternodes.get).thenReturn(storageMasternodes)
//                    when(mock.masternodes.set(any())).thenDoNothing()
//                    when(mock.masternodeListState.set(any())).thenDoNothing()
//                    when(mock.block(byHeaderHash: equal(to: blockHash))).thenReturn(block)
//                }
//                stub(mockMasternodeSortedList) { mock in
//                    when(mock.masternodes.get).thenReturn(resultMasternodes)
//                }
//                stub(mockMasternodeListMerkleRootCalculator) { mock in
//                    when(mock.calculateMerkleRoot(sortedMasternodes: equal(to: resultMasternodes))).thenReturn(calculatedHash)
//                }
//                stub(mockMasternodeCbTxHasher) { mock in
//                    when(mock.hash(coinbaseTransaction: equal(to: coinbaseTransaction))).thenReturn(calculatedHash)
//                }
//                stub(mockMerkleBranch) { mock in
//                    when(mock.calculateMerkleRoot(txCount: any(), hashes: any(), flags: any())).thenReturn((merkleRoot: correctMerkleRoot, matchedHashes: [calculatedHash]))
//                }
//            }
//
//            it("updates list with correct masternodes") {
//                try! manager.updateList(masternodeListDiffMessage: message)
//
//                verify(mockMasternodeSortedList).removeAll()
//
//                verify(mockStorage).masternodes.get()
//                verify(mockMasternodeSortedList).add(masternodes: equal(to: storageMasternodes))
//
//                verify(mockMasternodeSortedList).remove(by: equal(to: message.deletedMNs))
//                verify(mockMasternodeSortedList).add(masternodes: equal(to: mnList))
//
//                verify(mockMasternodeListMerkleRootCalculator).calculateMerkleRoot(sortedMasternodes: equal(to: resultMasternodes))
//                verify(mockMasternodeCbTxHasher).hash(coinbaseTransaction: equal(to: coinbaseTransaction))
//
//                verify(mockStorage).masternodeListState.set(equal(to: MasternodeListState(baseBlockHash: blockHash)))
//                verify(mockStorage).masternodes.set(equal(to: resultMasternodes))
//            }
//
//            it("calculates wrong merlkeHash") {
//                stub(mockMasternodeListMerkleRootCalculator) { mock in
//                    when(mock.calculateMerkleRoot(sortedMasternodes: equal(to: resultMasternodes))).thenReturn(Data(repeating: 1, count: 4))
//                }
//
//                do {
//                    try manager.updateList(masternodeListDiffMessage: message)
//                    XCTFail("must catch error!")
//                } catch let error as MasternodeListManager.ValidationError {
//                    XCTAssertEqual(error, DashKitErrors.MasternodeListValidation.wrongMerkleRootList)
//                } catch {
//                    XCTFail("Invalid Error thrown!")
//                }
//            }
//
//            it("calculates wrong coinbaseHash") {
//                stub(mockMerkleBranch) { mock in
//                    when(mock.calculateMerkleRoot(txCount: any(), hashes: any(), flags: any())).thenReturn((merkleRoot: correctMerkleRoot, matchedHashes: []))
//                }
//
//                do {
//                    try manager.updateList(masternodeListDiffMessage: message)
//                    XCTFail("must catch error!")
//                } catch let error as MasternodeListManager.ValidationError {
//                    XCTAssertEqual(error, DashKitErrors.MasternodeListValidation.wrongCoinbaseHash)
//                } catch {
//                    XCTFail("Invalid Error thrown!")
//                }
//            }
//
//            it("throws exception when block is not found") {
//                stub(mockStorage) { mock in
//                    when(mock.block(byHeaderHash: equal(to: blockHash))).thenReturn(nil)
//                }
//
//                do {
//                    try manager.updateList(masternodeListDiffMessage: message)
//                    XCTFail("must catch error!")
//                } catch let error as MasternodeListManager.ValidationError {
//                    XCTAssertEqual(error, DashKitErrors.MasternodeListValidation.noMerkleBlockHeader)
//                } catch {
//                    XCTFail("Invalid Error thrown!")
//                }
//            }
//
//            it("throws exception when header is not found") {
//                let block = Block()
//                stub(mockStorage) { mock in
//                    when(mock.block(byHeaderHash: equal(to: blockHash))).thenReturn(block)
//                }
//                do {
//                    try manager.updateList(masternodeListDiffMessage: message)
//                    XCTFail("must catch error!")
//                } catch let error as MasternodeListManager.ValidationError {
//                    XCTAssertEqual(error, DashKitErrors.MasternodeListValidation.noMerkleBlockHeader)
//                } catch {
//                    XCTFail("Invalid Error thrown!")
//                }
//            }
//
//            it("throws exception when calculated wrong coinbase merkle root") {
//                stub(mockMerkleBranch) { mock in
//                    when(mock.calculateMerkleRoot(txCount: any(), hashes: any(), flags: any())).thenReturn((merkleRoot: Data(repeating: 1, count: 32), matchedHashes: [calculatedHash]))
//                }
//
//                do {
//                    try manager.updateList(masternodeListDiffMessage: message)
//                    XCTFail("must catch error!")
//                } catch let error as MasternodeListManager.ValidationError {
//                    XCTAssertEqual(error, DashKitErrors.MasternodeListValidation.wrongMerkleRoot)
//                } catch {
//                    XCTFail("Invalid Error thrown!")
//                }
//            }
//        }
//
//    }
//
//    private func taskMessage(baseBlockHash: Data, blockHash: Data) -> MasternodeListDiffMessage {
//        let cbTx = CoinbaseTransaction(transaction: TestData.p2pkhTransaction, coinbaseTransactionSize: Data(bytes: [0]), version: 0, height: 0, merkleRootMNList: Data())
//
//        return MasternodeListDiffMessage(baseBlockHash: baseBlockHash, blockHash: blockHash,
//                totalTransactions: 0, merkleHashesCount: 0, merkleHashes: [],
//                merkleFlagsCount: 0, merkleFlags: Data(), cbTx: cbTx, deletedMNsCount: 0,
//                deletedMNs: [], mnListCount: 0, mnList: [])
//    }
//
//}
