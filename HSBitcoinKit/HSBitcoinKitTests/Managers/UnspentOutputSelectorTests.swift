import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class UnspentOutputSelectorTests: XCTestCase {

    private var unspentOutputSelector: UnspentOutputSelector!
    private var outputs: [TransactionOutput]!

    override func setUp() {
        super.setUp()

        let mockTransactionSizeCalculator = MockITransactionSizeCalculator()

        stub(mockTransactionSizeCalculator) { mock in
            when(mock.inputSize(type: any())).thenReturn(10)
            when(mock.outputSize(type: any())).thenReturn(2)
            when(mock.transactionSize(inputs: any(), outputScriptTypes: any())).thenReturn(100)
        }

        unspentOutputSelector = UnspentOutputSelector(calculator: mockTransactionSizeCalculator)

        outputs = [TransactionOutput(withValue: 1000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()),
                   TransactionOutput(withValue: 2000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()),
                   TransactionOutput(withValue: 4000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()),
                   TransactionOutput(withValue: 8000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()),
                   TransactionOutput(withValue: 16000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())
        ]
    }

    override func tearDown() {
        unspentOutputSelector = nil
        outputs = nil

        super.tearDown()
    }

    func testExactlyValueReceiverPay() {
        validExactlyTest(value: 4000, feeRate: 1, fee: 100, senderPay: false, output: outputs[2])         // exactly, without fee
        validExactlyTest(value: 4000 - 5, feeRate: 1, fee: 100, senderPay: false, output: outputs[2]) // in range using dust, without fee
        validExactlyTest(value: 3900, feeRate: 1, fee: 100, senderPay: true, output: outputs[2])          // exactly, with fee
        validExactlyTest(value: 3900 - 5, feeRate: 1, fee: 105, senderPay: true, output: outputs[2])  // in range using dust, with fee
    }

    func validExactlyTest(value: Int, feeRate: Int, fee: Int, senderPay: Bool, output: TransactionOutput) {
        do {
            let selectedOutputs = try unspentOutputSelector.select(value: value, feeRate: feeRate, senderPay: senderPay, outputs: outputs)
            XCTAssertEqual(selectedOutputs.outputs, [output])
            XCTAssertEqual(selectedOutputs.totalValue, output.value)
            XCTAssertEqual(selectedOutputs.fee, fee)
            XCTAssertEqual(selectedOutputs.addChangeOutput, false)
        } catch {
            XCTFail("Unexpected error!")
        }
    }

    func testSummaryValueReceiverPay() {
        do {
            let selectedOutputs = try unspentOutputSelector.select(value: 7000, feeRate: 1, senderPay: false, outputs: outputs)
            XCTAssertEqual(selectedOutputs.outputs, [outputs[0], outputs[1], outputs[2]])
            XCTAssertEqual(selectedOutputs.totalValue, 7000)
            XCTAssertEqual(selectedOutputs.fee, 100)
            XCTAssertEqual(selectedOutputs.addChangeOutput, false)
        } catch {
            XCTFail("Unexpected error!")
        }
    }

    func testSummaryValueSenderPay() {
        // with change output
        do {
            let selectedOutputs = try unspentOutputSelector.select(value: 7000, feeRate: 1, senderPay: true, outputs: outputs)
            XCTAssertEqual(selectedOutputs.outputs, [outputs[0], outputs[1], outputs[2], outputs[3]])
            XCTAssertEqual(selectedOutputs.totalValue, 15000)
            XCTAssertEqual(selectedOutputs.fee, 100)
            XCTAssertEqual(selectedOutputs.addChangeOutput, true)
        } catch {
            XCTFail("Unexpected error!")
        }
        // without change output
        do {
            let expectedFee = 100 + 10 + 2  // fee for tx + fee for change input + fee for change output
            let selectedOutputs = try unspentOutputSelector.select(value: 15000 - expectedFee, feeRate: 1, senderPay: true, outputs: outputs)
            XCTAssertEqual(selectedOutputs.outputs, [outputs[0], outputs[1], outputs[2], outputs[3]])
            XCTAssertEqual(selectedOutputs.totalValue, 15000)
            XCTAssertEqual(selectedOutputs.fee, expectedFee)
            XCTAssertEqual(selectedOutputs.addChangeOutput, false)
        } catch {
            XCTFail("Unexpected error!")
        }
    }

    func testNotEnoughErrorReceiverPay() {
        do {
            _ = try unspentOutputSelector.select(value: 31001, feeRate: 1, senderPay: false, outputs: outputs)
            XCTFail("Wrong value summary!")
        } catch let error as SelectorError {
            XCTAssertEqual(error, SelectorError.notEnough(maxFee: 0))
        } catch {
            XCTFail("Unexpected \(error) error!")
        }
    }

    func testNotEnoughErrorSenderPay() {
        do {
            _ = try unspentOutputSelector.select(value: 30901, feeRate: 1, senderPay: true, outputs: outputs)
            XCTFail("Wrong value summary!")
        } catch let error as SelectorError {
            XCTAssertEqual(error, SelectorError.notEnough(maxFee: 100))
        } catch {
            XCTFail("Unexpected \(error) error!")
        }
    }

    func testEmptyOutputsError() {
        do {
            _ = try unspentOutputSelector.select(value: 100, feeRate: 1, senderPay: false, outputs: [])
            XCTFail("Wrong value summary!")
        } catch let error as SelectorError {
            XCTAssertEqual(error, SelectorError.emptyOutputs)
        } catch {
            XCTFail("Unexpected \(error) error!")
        }
    }

}
