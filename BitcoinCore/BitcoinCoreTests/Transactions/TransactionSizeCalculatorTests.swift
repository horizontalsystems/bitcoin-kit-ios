import XCTest
import Cuckoo
@testable import BitcoinCore

class TransactionSizeCalculatorTests: XCTestCase {
    var calculator: TransactionSizeCalculator!

    override func setUp() {
        super.setUp()

        calculator = TransactionSizeCalculator()
    }

    override func tearDown() {
        calculator = nil

        super.tearDown()
    }

    func testTransactionSize() {
        XCTAssertEqual(calculator.transactionSize(inputs: [], outputScriptTypes: []), 10) // empty legacy tx
        XCTAssertEqual(calculator.transactionSize(inputs: [.p2pkh], outputScriptTypes: [.p2pkh]), 194) // 1-in 1-out standart tx
        XCTAssertEqual(calculator.transactionSize(inputs: [.p2pkh, .p2pk], outputScriptTypes: [.p2pkh]), 310) // 2-in 1-out legacy tx
        XCTAssertEqual(calculator.transactionSize(inputs: [.p2pkh, .p2pk], outputScriptTypes: [.p2wpkh]), 307) // 2-in 1-out legacy tx with witness output
        XCTAssertEqual(calculator.transactionSize(inputs: [.p2pkh, .p2pk], outputScriptTypes: [.p2pkh, .p2pk]), 354) // 2-in 2-out legacy tx

        XCTAssertEqual(calculator.transactionSize(inputs: [.p2wpkh], outputScriptTypes: [.p2pkh]), 113) // 1-in 1-out witness tx
        XCTAssertEqual(calculator.transactionSize(inputs: [.p2wpkhSh], outputScriptTypes: [.p2pkh]), 136) // 1-in 1-out (sh) witness tx
        XCTAssertEqual(calculator.transactionSize(inputs: [.p2wpkh, .p2pkh], outputScriptTypes: [.p2pkh]), 263) // 2-in 1-out witness tx
    }

    func testInputSize() {
        XCTAssertEqual(calculator.inputSize(type: .p2pkh), 150)
        XCTAssertEqual(calculator.inputSize(type: .p2pk), 116)
        XCTAssertEqual(calculator.inputSize(type: .p2wpkh), 41)
        XCTAssertEqual(calculator.inputSize(type: .p2wpkhSh), 64)
    }

    func testOutputSize() {
        XCTAssertEqual(calculator.outputSize(type: .p2pkh), 34)
        XCTAssertEqual(calculator.outputSize(type: .p2sh), 32)
        XCTAssertEqual(calculator.outputSize(type: .p2pk), 44)
        XCTAssertEqual(calculator.outputSize(type: .p2wpkh), 31)
        XCTAssertEqual(calculator.outputSize(type: .p2wpkhSh), 32)
    }

}
