//import XCTest
//import Cuckoo
//@testable import HSBitcoinKit
//
//class TransactionLinkerTests: XCTestCase {
//
//    private var linker: TransactionLinker!
//
//    private var realm: Realm!
//    private var previousTransaction: Transaction!
//    private var pubKeyHash = Data(hex: "1ec865abcb88cec71c484d4dadec3d7dc0271a7b")!
//
//    override func setUp() {
//        super.setUp()
//
//        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
//        try! realm.write { realm.deleteAll() }
//
//        linker = TransactionLinker()
//        previousTransaction = TestData.p2pkhTransaction
//
//        try! realm.write {
//            realm.add(previousTransaction)
//        }
//    }
//
//    override func tearDown() {
//        linker = nil
//        realm = nil
//        previousTransaction = nil
//
//        super.tearDown()
//    }
//
//    func testHandle_HasPreviousOutput() {
//        try! realm.write {
//            previousTransaction.outputs.first!.publicKey = TestData.pubKey()
//            previousTransaction.outputs.first!.address = "address"
//        }
//
//        let input = TransactionInput()
//        input.previousOutputTxReversedHex = previousTransaction.dataHashReversedHex
//        input.previousOutputIndex = previousTransaction.outputs.first!.index
//        input.sequence = 100
//
//        let transaction = Transaction()
//        transaction.dataHashReversedHex = "0000000000000000000111111111111122222222222222333333333333333000"
//        transaction.inputs.append(input)
//
//        try! realm.write {
//            realm.add(previousTransaction, update: true)
//            realm.add(transaction, update: true)
//        }
//
//        XCTAssertEqual(transaction.isMine, false)
//        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
//        XCTAssertEqual(transaction.inputs.first!.address, nil)
//        XCTAssertEqual(transaction.inputs.first!.keyHash, nil)
//        try? realm.write {
//            linker.handle(transaction: transaction, realm: realm)
//        }
//        XCTAssertEqual(transaction.isMine, true)
//        assertOutputEqual(out1: transaction.inputs.first!.previousOutput!, out2: previousTransaction.outputs.first!)
//    }
//
//    func testHandle_HasPreviousOutputWhichIsNotMine() {
//        let input = TransactionInput()
//        input.previousOutputTxReversedHex = previousTransaction.dataHashReversedHex
//        input.previousOutputIndex = previousTransaction.outputs.first!.index
//        input.sequence = 100
//
//        let transaction = Transaction()
//        transaction.dataHashReversedHex = "0000000000000000000111111111111122222222222222333333333333333000"
//        transaction.inputs.append(input)
//
//        try! realm.write {
//            realm.add(previousTransaction, update: true)
//            realm.add(transaction, update: true)
//        }
//
//        XCTAssertEqual(transaction.isMine, false)
//        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
//        XCTAssertEqual(transaction.inputs.first!.address, nil)
//        XCTAssertEqual(transaction.inputs.first!.keyHash, nil)
//        try? realm.write {
//            linker.handle(transaction: transaction, realm: realm)
//        }
//        XCTAssertEqual(transaction.isMine, false)
//        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
//    }
//
//    func testHandle_HasNotPreviousOutput() {
//        let input = TransactionInput()
//        input.previousOutputTxReversedHex = TestData.p2pkTransaction.dataHashReversedHex
//        input.previousOutputIndex = TestData.p2pkTransaction.outputs.first!.index
//        input.sequence = 100
//
//        let transaction = Transaction()
//        transaction.dataHashReversedHex = "0000000000000000000111111111111122222222222222333333333333333000"
//        transaction.inputs.append(input)
//
//        try! realm.write {
//            realm.add(previousTransaction, update: true)
//            realm.add(transaction, update: true)
//        }
//
//        XCTAssertEqual(transaction.isMine, false)
//        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
//        try? realm.write {
//            linker.handle(transaction: transaction, realm: realm)
//        }
//        XCTAssertEqual(transaction.isMine, false)
//        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
//    }
//
//    private func assertOutputEqual(out1: Output, out2: Output) {
//        XCTAssertEqual(out1.value, out2.value)
//        XCTAssertEqual(out1.lockingScript, out2.lockingScript)
//        XCTAssertEqual(out1.index, out2.index)
//    }
//
//}
