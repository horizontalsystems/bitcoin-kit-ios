//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class MerkleBlockValidatorTests: XCTestCase {
//    private var mockStorage: MockIStorage!
//    private var validator: MerkleBlockValidator!
//    private var blockHeader: BlockHeader!
//    private var matchedHash: Data!
//    private var totalTransactions: UInt32!
//    private var numberOfHashes: VarInt!
//    private var hashes: [Data]!
//    private var numberOfFlags: VarInt!
//    private var flags: [UInt8]!
//
//    private var mockMerkleBranch: MockIMerkleBranch!
//
//    override func setUp() {
//        super.setUp()
//
//        mockMerkleBranch = MockIMerkleBranch() // use real hasher function for real test data
//
//        blockHeader = BlockHeader(version: 0, headerHash: Data(), previousBlockHeaderHash: Data(), merkleRoot: Data(repeating: 9, count: 32), timestamp: 0, bits: 0, nonce: 0)
//
//        totalTransactions = 10
//        numberOfHashes = 10
//
//        hashes = [
//            Data(repeating: 0, count: 32),
//            Data(repeating: 1, count: 32)
//        ]
//
//        numberOfFlags = 3
//        flags = [223, 22, 0]
//
//        matchedHash = Data(repeating: 5, count: 32)
//
//        stub(mockMerkleBranch) { mock in
//            when(mock.calculateMerkleRoot(txCount: any(), hashes: any(), flags: any())).thenReturn((merkleRoot: blockHeader.merkleRoot, matchedHashes: [matchedHash]))
//        }
//
//        validator = MerkleBlockValidator(maxBlockSize: 1_000_000, merkleBranch: mockMerkleBranch)
//    }
//
//    override func tearDown() {
//        mockMerkleBranch = nil
//
//        validator = nil
//        super.tearDown()
//    }
//
//    private func getSampleMessage() -> MerkleBlockMessage {
//        return MerkleBlockMessage(
//                blockHeader: blockHeader, totalTransactions: totalTransactions,
//                numberOfHashes: numberOfHashes, hashes: hashes, numberOfFlags: numberOfFlags, flags: flags
//        )
//    }
//
//
//    func testValidMerkleBlock() {
//        do {
//            let data = try validator.merkleBlock(from: getSampleMessage())
//
//            XCTAssertEqual(data.transactionHashes.count, 1)
//            XCTAssertEqual(data.transactionHashes[0], matchedHash)
//        } catch {
//            XCTFail("Should be valid")
//        }
//    }
//
//    func testTxIdsClearedFirst() {
//        var txIds = [Data]()
//        do {
//            txIds = try validator.merkleBlock(from: getSampleMessage()).transactionHashes
//            txIds = try validator.merkleBlock(from: getSampleMessage()).transactionHashes
//        } catch {
//            XCTFail("Should be valid")
//        }
//
//        XCTAssertEqual(txIds.count, 1)
//        XCTAssertEqual(txIds[0], matchedHash)
//    }
//
//    func testWrongMerkleRoot() {
//        blockHeader = BlockHeader(version: 0, headerHash: Data(repeating: 9, count: 32), previousBlockHeaderHash: Data(),
//                merkleRoot: Data(hex: "0000000000000000000000000000000000000000000000000000000000000001")!,
//                timestamp: 0, bits: 0, nonce: 0)
//
//        var caught = false
//        do {
//            _ = try validator.merkleBlock(from: getSampleMessage()).transactionHashes
//        } catch let error as MerkleBlockValidator.ValidationError {
//            caught = true
//            XCTAssertEqual(error, MerkleBlockValidator.DashKitErrors.MasternodeListValidation.wrongMerkleRoot)
//        } catch {
//            XCTFail("Unknown Exception")
//        }
//
//        if !caught {
//            XCTFail("Should Throw Exception")
//        }
//    }
//
//    func testNoTransactions() {
//        totalTransactions = 0
//
//        do {
//            _ = try validator.merkleBlock(from: getSampleMessage()).transactionHashes
//            XCTFail("Should Throw Exception")
//        } catch let error as MerkleBlockValidator.ValidationError {
//            XCTAssertEqual(error, MerkleBlockValidator.DashKitErrors.MasternodeListValidation.noTransactions)
//        } catch {
//            XCTFail("Unknown Exception")
//        }
//    }
//
//    func testTooManyTransactions() {
//        totalTransactions = 1_000_000 / 60 + 1
//
//        do {
//            _ = try validator.merkleBlock(from: getSampleMessage()).transactionHashes
//            XCTFail("Should Throw Exception")
//        } catch let error as MerkleBlockValidator.ValidationError {
//            XCTAssertEqual(error, MerkleBlockValidator.DashKitErrors.MasternodeListValidation.tooManyTransactions)
//        } catch {
//            XCTFail("Unknown Exception")
//        }
//    }
//
//    func testMoreHashesThanTransactions() {
//        totalTransactions = 1
//
//        do {
//            _ = try validator.merkleBlock(from: getSampleMessage()).transactionHashes
//            XCTFail("Should Throw Exception")
//        } catch let error as MerkleBlockValidator.ValidationError {
//            XCTAssertEqual(error, MerkleBlockValidator.DashKitErrors.MasternodeListValidation.moreHashesThanTransactions)
//        } catch {
//            XCTFail("Unknown Exception")
//        }
//    }
//
//    func testMatchedBitsFewerThanHashes() {
//        flags = [200]
//        for i in 0..<7 { hashes.append(Data(repeating: UInt8(i), count: 32)) }
//
//        do {
//            _ = try validator.merkleBlock(from: getSampleMessage()).transactionHashes
//            XCTFail("Should Throw Exception")
//        } catch let error as MerkleBlockValidator.ValidationError {
//            XCTAssertEqual(error, MerkleBlockValidator.DashKitErrors.MasternodeListValidation.matchedBitsFewerThanHashes)
//        } catch {
//            XCTFail("Unknown Exception")
//        }
//    }
//
//}
