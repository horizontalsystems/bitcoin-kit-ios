import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionExtractorTests: XCTestCase {

    private var firstExtractor: MockIScriptExtractor!
    private var secondExtractor: MockIScriptExtractor!
    private var realm: Realm!

    private var addressConverter: MockIAddressConverter!
    private var scriptConverter: MockIScriptConverter!
    private var inputExtractors: [IScriptExtractor]!
    private var outputExtractors: [IScriptExtractor]!
    private var extractor: TransactionExtractor!

    private var transaction: Transaction!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        firstExtractor = MockIScriptExtractor()
        stub(firstExtractor) { mock in
            when(mock.type.get).thenReturn(.unknown)
            when(mock.extract(from: any(), converter: any())).thenThrow(ScriptError.wrongScriptLength)
        }
        secondExtractor = MockIScriptExtractor()
        stub(secondExtractor) { mock in
            when(mock.type.get).thenReturn(.unknown)
            when(mock.extract(from: any(), converter: any())).thenThrow(ScriptError.wrongScriptLength)
        }
        addressConverter = MockIAddressConverter()
        scriptConverter = MockIScriptConverter()

        inputExtractors = [firstExtractor, secondExtractor]
        outputExtractors = [firstExtractor, secondExtractor]

        extractor = TransactionExtractor(scriptInputExtractors: inputExtractors, scriptOutputExtractors: outputExtractors, scriptConverter: scriptConverter, addressConverter: addressConverter)

        stub(scriptConverter) { mock in
            when(mock.decode(data: any())).thenReturn(Script(with: Data(), chunks: []))
        }
        stub(addressConverter) { mock in
            when(mock.convert(keyHash: any(), type: any())).thenReturn(LegacyAddress(type: .pubKeyHash, keyHash: Data(), base58: ""))
        }

        transaction = TestData.p2pkhTransaction
    }

    override func tearDown() {
        extractor = nil
        realm = nil
        inputExtractors = nil
        outputExtractors = nil
        addressConverter = nil
        scriptConverter = nil
        realm = nil

        transaction = nil

        super.tearDown()
    }

    func testExtractP2Transaction() {
        let transactionTypes: [ScriptType] = [.p2pkh, .p2pk, .p2sh, .p2wpkh, .p2wsh]
        let address = LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "0000")!, base58: "0000")
        let publicKey = PublicKey()
        publicKey.keyHash = address.keyHash
        try? realm.write {
            realm.add(publicKey)
        }
        for type in transactionTypes {
            stub(secondExtractor) { mock in
                when(mock.type.get).thenReturn(type)
                when(mock.extract(from: any(), converter: any())).thenReturn(address.keyHash)
            }
            stub(addressConverter) { mock in
                when(mock.convert(keyHash: any(), type: any())).thenReturn(address)
            }
            extractor.extract(transaction: transaction, realm: realm)

            XCTAssertEqual(transaction.outputs[0].keyHash!, address.keyHash)
            XCTAssertEqual(transaction.outputs[0].address!, address.stringValue)
            XCTAssertEqual(transaction.outputs[0].scriptType, type)

            XCTAssertEqual(transaction.inputs[0].keyHash!, address.keyHash)
            XCTAssertEqual(transaction.inputs[0].address!, address.stringValue)
        }
    }

    func testExtractP2WPKHSHTransaction() {
        let address = LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "0000")!, base58: "0000")
        let publicKey = PublicKey()
        publicKey.scriptHashForP2WPKH = address.keyHash
        let rightKeyHash = Data(hex: "1111")!
        publicKey.keyHash = rightKeyHash
        try? realm.write {
            realm.add(publicKey)
        }
        stub(secondExtractor) { mock in
            when(mock.type.get).thenReturn(.p2wpkh)
            when(mock.extract(from: any(), converter: any())).thenReturn(address.keyHash)
        }
        stub(addressConverter) { mock in
            when(mock.convert(keyHash: any(), type: any())).thenReturn(address)
        }
        extractor.extract(transaction: transaction, realm: realm)

        XCTAssertEqual(transaction.outputs[0].keyHash!, rightKeyHash)
        XCTAssertEqual(transaction.outputs[0].address!, address.stringValue)
        XCTAssertEqual(transaction.outputs[0].scriptType, .p2wpkhSh)

        XCTAssertEqual(transaction.inputs[0].keyHash!, address.keyHash)
        XCTAssertEqual(transaction.inputs[0].address!, address.stringValue)
    }

    func testSecondExtractorCallingCount() {
        let address = LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "0000")!, base58: "0000")
        stub(firstExtractor) { mock in
            when(mock.type.get).thenReturn(.p2pkh)
            when(mock.extract(from: any(), converter: any())).thenReturn(address.keyHash)
        }
        stub(addressConverter) { mock in
            when(mock.convert(keyHash: any(), type: any())).thenReturn(address)
        }
        extractor.extract(transaction: transaction, realm: realm)
        verify(firstExtractor, times(transaction.outputs.count + transaction.inputs.count)).extract(from: any(), converter: any())
        verify(secondExtractor, never()).extract(from: any(), converter: any())
    }

    func testExtractUnknownTransaction() {
        extractor.extract(transaction: transaction, realm: realm)

        XCTAssertEqual(transaction.outputs[0].keyHash, TestData.p2pkhTransaction.outputs[0].keyHash)
        XCTAssertEqual(transaction.outputs[0].address, TestData.p2pkhTransaction.outputs[0].address)
        XCTAssertEqual(transaction.outputs[0].scriptType, TestData.p2pkhTransaction.outputs[0].scriptType)
    }

}
