import XCTest
import Cuckoo
@testable import BitcoinCore

class TransactionOutputExtractorTests: XCTestCase {
    private var extractor: TransactionOutputExtractor!

    private var mockPublicKeySetter: MockITransactionPublicKeySetter!
    private var mockPluginManager: MockIPluginManager!

    private var transaction: FullTransaction!

    override func setUp() {
        super.setUp()

        mockPublicKeySetter = MockITransactionPublicKeySetter()
        mockPluginManager = MockIPluginManager()
        stub(mockPublicKeySetter) { mock in
            when(mock.set(output: any())).thenReturn(false)
        }
        stub(mockPluginManager) { mock in
            when(mock.processTransactionWithNullData(transaction: any(), nullDataOutput: any())).thenDoNothing()
        }

        extractor = TransactionOutputExtractor(transactionKeySetter: mockPublicKeySetter, pluginManager: mockPluginManager)
        transaction = TestData.p2pkhTransaction
    }

    override func tearDown() {
        mockPublicKeySetter = nil
        mockPluginManager = nil

        extractor = nil
        transaction = nil

        super.tearDown()
    }

    func testExtractP2PKH() {
        let keyHash = Data(hex: "1ec865abcb88cec71c484d4dadec3d7dc0271a7b")!
        transaction.outputs[0].lockingScript = Data(hex: "76a9141ec865abcb88cec71c484d4dadec3d7dc0271a7b88ac")!

        extractor.extract(transaction: transaction)
        XCTAssertEqual(transaction.header.isMine, false)
        XCTAssertEqual(transaction.outputs[0].keyHash, keyHash)
        XCTAssertEqual(transaction.outputs[0].scriptType, ScriptType.p2pkh)
    }

    func testExtractP2PKH_isMine() {
        stub(mockPublicKeySetter) { mock in
            when(mock.set(output: any())).thenReturn(true)
        }
        let keyHash = Data(hex: "1ec865abcb88cec71c484d4dadec3d7dc0271a7b")!
        transaction.outputs[0].lockingScript = Data(hex: "76a9141ec865abcb88cec71c484d4dadec3d7dc0271a7b88ac")!

        extractor.extract(transaction: transaction)
        XCTAssertEqual(transaction.header.isMine, true)
        XCTAssertEqual(transaction.outputs[0].keyHash, keyHash)
        XCTAssertEqual(transaction.outputs[0].scriptType, ScriptType.p2pkh)
    }

    func testExtractP2PK() {
        let keyHash = Data(hex: "037d56797fbe9aa506fc263751abf23bb46c9770181a6059096808923f0a64cb15")!
        transaction.outputs[0].lockingScript = Data(hex: "21037d56797fbe9aa506fc263751abf23bb46c9770181a6059096808923f0a64cb15ac")!

        extractor.extract(transaction: transaction)
        XCTAssertEqual(transaction.outputs[0].keyHash, keyHash)
        XCTAssertEqual(transaction.outputs[0].scriptType, ScriptType.p2pk)
    }

    func testExtractP2SH() {
        let keyHash = Data(hex: "bd82ef4973ebfcbc8f7cb1d540ef0503a791970b")!
        transaction.outputs[0].lockingScript = Data(hex: "a914bd82ef4973ebfcbc8f7cb1d540ef0503a791970b87")!

        extractor.extract(transaction: transaction)
        XCTAssertEqual(transaction.outputs[0].keyHash, keyHash)
        XCTAssertEqual(transaction.outputs[0].scriptType, ScriptType.p2sh)
    }

    func testExtractP2WPKH() {
        let keyHash = Data(hex: "00148749115073ad59a6f3587f1f9e468adedf01473f")!
        transaction.outputs[0].lockingScript = keyHash

        extractor.extract(transaction: transaction)
        XCTAssertEqual(transaction.outputs[0].keyHash, keyHash)
        XCTAssertEqual(transaction.outputs[0].scriptType, ScriptType.p2wpkh)
    }

    func testExtractNullData() {
        let keyHash = Data(hex: "6a51020100147288e43af7997b486f5d2e4ac50bab99b9187807")!
        transaction.outputs[0].lockingScript = keyHash

        extractor.extract(transaction: transaction)
        XCTAssertEqual(transaction.outputs[0].keyHash, keyHash)
        XCTAssertEqual(transaction.outputs[0].scriptType, ScriptType.nullData)
        verify(mockPluginManager).processTransactionWithNullData(transaction: equal(to: transaction), nullDataOutput: equal(to: transaction.outputs[0]))
    }

}
