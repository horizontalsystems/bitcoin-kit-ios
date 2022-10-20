import XCTest
import Cuckoo
@testable import BitcoinCore

class TransactionInputExtractorTests: XCTestCase {

    private var addressConverter: MockIAddressConverter!
    private var scriptConverter: MockIScriptConverter!
    private var storage: MockIStorage!

    private var extractor: TransactionInputExtractor!

    override func setUp() {
        super.setUp()

        addressConverter = MockIAddressConverter()
        scriptConverter = MockIScriptConverter()
        storage = MockIStorage()
        stub(storage) { mock in
            when(mock.previousOutput(ofInput: any())).thenReturn(nil)
        }

        extractor = TransactionInputExtractor(storage: storage, scriptConverter: scriptConverter, addressConverter: addressConverter)

        stub(scriptConverter) { mock in
            when(mock.decode(data: any())).thenThrow(ScriptError.wrongScriptLength)
        }
    }

    override func tearDown() {
        extractor = nil
        addressConverter = nil
        scriptConverter = nil
        storage = nil

        super.tearDown()
    }

    func testExtractP2PKHTransaction() {
        let address = LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "00112233")!, base58: "test_string_value")
        stub(addressConverter) { mock in
            when(mock.convert(keyHash: any(), type: any())).thenReturn(address)
        }
        let tx = TestData.p2pkhTransaction
        extractor.extract(transaction: tx)

        XCTAssertEqual(tx.inputs[0].keyHash!, address.keyHash)
        XCTAssertEqual(tx.inputs[0].address!, address.stringValue)
    }

    func testExtractP2WPKHSHTransaction() {
        let address = LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "00112233")!, base58: "test_string_value")
        stub(addressConverter) { mock in
            when(mock.convert(keyHash: any(), type: any())).thenReturn(address)
        }
        let tx = TestData.p2pkhTransaction
        tx.inputs[0].signatureScript = Data(hex: "1600148749115073ad59a6f3587f1f9e468adedf01473f")!
        extractor.extract(transaction: tx)

        XCTAssertEqual(tx.inputs[0].keyHash!, address.keyHash)
        XCTAssertEqual(tx.inputs[0].address!, address.stringValue)

        tx.inputs[0].keyHash = nil
        tx.inputs[0].address = nil
        tx.inputs[0].signatureScript = Data(hex: "1660148749115073ad59a6f3587f1f9e468adedf01473f")!
        extractor.extract(transaction: tx)

        XCTAssertEqual(tx.inputs[0].keyHash!, address.keyHash)
        XCTAssertEqual(tx.inputs[0].address!, address.stringValue)
    }

    func testExtractP2SHTransaction() {
        let address = LegacyAddress(type: .scriptHash, keyHash: Data(hex: "00112233")!, base58: "test_string_value")
        stub(addressConverter) { mock in
            when(mock.convert(keyHash: any(), type: any())).thenReturn(address)
        }
        let redeemData = Data(hex: "00000000")!
        let signatureScript = Data(hex: "1600148749115073ad59a6f3587f1f9e468adedf01473f")!

        let script = Script(with: address.keyHash, chunks: [Chunk(scriptData: redeemData, index: 0, payloadRange: 0..<4)])
        let redeemScript = Script(with: address.keyHash, chunks: [Chunk(scriptData: Data([OpCode.checkSig]), index: 0), Chunk(scriptData: Data([OpCode.endIf]), index: 0)])
        stub(scriptConverter) { mock in
            when(mock.decode(data: equal(to: signatureScript))).thenReturn(script)
            when(mock.decode(data: equal(to: redeemData))).thenReturn(redeemScript)
        }

        let tx = TestData.p2pkhTransaction
        tx.inputs[0].signatureScript = signatureScript
        extractor.extract(transaction: tx)

        XCTAssertEqual(tx.inputs[0].keyHash!, address.keyHash)
        XCTAssertEqual(tx.inputs[0].address!, address.stringValue)
    }

}