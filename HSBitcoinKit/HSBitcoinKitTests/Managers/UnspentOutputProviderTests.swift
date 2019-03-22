import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class UnspentOutputProviderTests: XCTestCase {

    private var realm: Realm!

    private var outputs: [Output]!
    private var unspentOutputProvider: UnspentOutputProvider!
    private var pubKey: PublicKey!

    private let lastBlockHeight = 550368
    private let confirmationsThreshold = 6

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))

        let lastBlock = Block(withHeader: BlockHeader(), height: lastBlockHeight)
        lastBlock.headerHashReversedHex = "123"
        try! realm.write {
            realm.deleteAll()
            realm.add(lastBlock)
        }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        pubKey = TestData.pubKey()

        unspentOutputProvider = UnspentOutputProvider(realmFactory: mockRealmFactory, confirmationsThreshold: confirmationsThreshold)
        outputs = [Output(withValue: 1, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data(hex: "000010000")!),
                   Output(withValue: 2, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data(hex: "000010001")!),
                   Output(withValue: 4, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data(hex: "000010002")!),
                   Output(withValue: 8, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data(hex: "000010003")!),
                   Output(withValue: 16, index: 0, lockingScript: Data(), type: .p2sh, keyHash: Data(hex: "000010004")!)
        ]
    }

    override func tearDown() {
        realm = nil

        unspentOutputProvider = nil
        outputs = nil
        pubKey = nil

        super.tearDown()
    }

    func testValidOutputs() {
        outputs.forEach { $0.publicKey = pubKey }

        let transaction = Transaction(version: 0, inputs: [], outputs: outputs)
        let block = Block(withHeader: BlockHeader(), height: lastBlockHeight - confirmationsThreshold)
        transaction.block = block

        try? realm.write {
            realm.add(transaction, update: true)
        }
        let inputTransaction = Transaction(version: 0, inputs: inputsWithPreviousOutputs(range: 0..<2), outputs: [])
        try? realm.write {
            realm.add(inputTransaction, update: true)
        }
        let unspentOutputs = unspentOutputProvider.allUnspentOutputs
        XCTAssertEqual(unspentOutputs[0].keyHash, outputs[2].keyHash)
        XCTAssertEqual(unspentOutputs[1].keyHash, outputs[3].keyHash)
        XCTAssertEqual(unspentOutputs[2].keyHash, outputs[4].keyHash)
    }

    func testHeightWrongOutputs() {
        outputs.forEach { $0.publicKey = pubKey }

        let transaction = Transaction(version: 0, inputs: [], outputs: outputs)
        let block = Block(withHeader: BlockHeader(), height: lastBlockHeight - 1)
        transaction.block = block

        try? realm.write {
            realm.add(transaction, update: true)
        }
        let inputTransaction = Transaction(version: 0, inputs: inputsWithPreviousOutputs(range: 0..<2), outputs: [])
        try? realm.write {
            realm.add(inputTransaction, update: true)
        }

        let unspentOutputs = unspentOutputProvider.allUnspentOutputs
        XCTAssertEqual(unspentOutputs.count, 0)
    }

    func testOutgoingOutputs() {
        outputs.forEach { $0.publicKey = pubKey }

        let transaction = Transaction(version: 0, inputs: [], outputs: outputs)
        let block = Block(withHeader: BlockHeader(), height: lastBlockHeight - 1)
        transaction.block = block
        transaction.isOutgoing = true

        try? realm.write {
            realm.add(transaction, update: true)
        }
        let inputTransaction = Transaction(version: 0, inputs: inputsWithPreviousOutputs(range: 0..<2), outputs: [])
        try? realm.write {
            realm.add(inputTransaction, update: true)
        }

        let unspentOutputs = unspentOutputProvider.allUnspentOutputs

        XCTAssertEqual(unspentOutputs[0].keyHash, outputs[2].keyHash)
        XCTAssertEqual(unspentOutputs[1].keyHash, outputs[3].keyHash)
        XCTAssertEqual(unspentOutputs[2].keyHash, outputs[4].keyHash)
    }

    func testEmptyMineOutputs() {
        let transaction = Transaction(version: 0, inputs: [], outputs: outputs)
        try? realm.write {
            realm.add(transaction, update: true)
        }
        let inputTransaction = Transaction(version: 0, inputs: inputsWithPreviousOutputs(range: 3..<4), outputs: [])
        try? realm.write {
            realm.add(inputTransaction, update: true)
        }
        let unspentOutputs = unspentOutputProvider.allUnspentOutputs
        XCTAssertEqual(unspentOutputs.count, 0)
    }

    func testBalance() {
        outputs.forEach { $0.publicKey = pubKey }

        let transaction = Transaction(version: 0, inputs: [], outputs: outputs)
        let block = Block(withHeader: BlockHeader(), height: lastBlockHeight - 1)
        transaction.block = block
        transaction.isOutgoing = true

        try? realm.write {
            realm.add(transaction, update: true)
        }
        let inputTransaction = Transaction(version: 0, inputs: inputsWithPreviousOutputs(range: 0..<2), outputs: [])
        try? realm.write {
            realm.add(inputTransaction, update: true)
        }

        XCTAssertEqual(unspentOutputProvider.balance, outputs[2].value + outputs[3].value + outputs[4].value)
    }

    private func inputsWithPreviousOutputs(range: Range<Int>) -> [Input] {
        let transaction = outputs[0].transaction!
        var inputs = [Input]()
        for i in range.lowerBound..<range.upperBound {
            let input = TestData.transactionInput(previousTransaction: transaction, previousOutput: outputs[i], script: Data(), sequence: 2)
            inputs.append(input)
        }
        return inputs
    }

}
