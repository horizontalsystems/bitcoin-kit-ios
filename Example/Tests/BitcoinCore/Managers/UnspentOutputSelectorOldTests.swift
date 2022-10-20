import XCTest
import Cuckoo
@testable import BitcoinCore

class UnspentOutputSelectorOldTests: XCTestCase {

    private let dust = 12

    private var unspentOutputSelector: UnspentOutputSelector!
    private var outputs: [UnspentOutput]!

    var mockTransactionSizeCalculator: MockITransactionSizeCalculator!
    var mockUnspentOutputProvider: MockIUnspentOutputProvider!
    var mockDustCalculator: MockIDustCalculator!

    override func setUp() {
        super.setUp()

        mockTransactionSizeCalculator = MockITransactionSizeCalculator()
        mockUnspentOutputProvider = MockIUnspentOutputProvider()
        mockDustCalculator = MockIDustCalculator()

        stub(mockTransactionSizeCalculator) { mock in
            when(mock.inputSize(type: any())).thenReturn(10)
            when(mock.outputSize(type: any())).thenReturn(2)
            when(mock.transactionSize(previousOutputs: any(), outputScriptTypes: any(), pluginDataOutputSize: 0)).thenReturn(100)
        }
        unspentOutputSelector = UnspentOutputSelector(calculator: mockTransactionSizeCalculator, provider: mockUnspentOutputProvider, dustCalculator: mockDustCalculator)

        outputs = [TestData.unspentOutput(output: Output(withValue: 1000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                   TestData.unspentOutput(output: Output(withValue: 2000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                   TestData.unspentOutput(output: Output(withValue: 4000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                   TestData.unspentOutput(output: Output(withValue: 8000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data())),
                   TestData.unspentOutput(output: Output(withValue: 16000, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data()))
        ]
        stub(mockUnspentOutputProvider) { mock in
            when(mock.spendableUtxo.get).thenReturn(outputs)
        }
        stub(mockDustCalculator) { mock in
            when(mock.dust(type: any())).thenReturn(dust)
        }
    }

    override func tearDown() {
        unspentOutputSelector = nil
        mockUnspentOutputProvider = nil
        mockTransactionSizeCalculator = nil
        outputs = nil

        super.tearDown()
    }

    func testSummaryValueReceiverPay() {
        do {
            let selectedOutputs = try unspentOutputSelector.select(value: 7000, feeRate: 1, senderPay: false, pluginDataOutputSize: 0)
            XCTAssertEqual(selectedOutputs.unspentOutputs, [outputs[0], outputs[1], outputs[2]])
            XCTAssertEqual(selectedOutputs.recipientValue, 7000 - 100)
            XCTAssertEqual(selectedOutputs.changeValue, nil)
        } catch {
            XCTFail("Unexpected error!")
        }
    }

    func testSummaryValueSenderPay() {
        // with change output
        do {
            let selectedOutputs = try unspentOutputSelector.select(value: 7000, feeRate: 1, senderPay: true, pluginDataOutputSize: 0)
            XCTAssertEqual(selectedOutputs.unspentOutputs, [outputs[0], outputs[1], outputs[2], outputs[3]])
            XCTAssertEqual(selectedOutputs.recipientValue, 7000)
            XCTAssertEqual(selectedOutputs.changeValue, 15000 - 7000 - 100)
        } catch {
            XCTFail("Unexpected error!")
        }
        // without change output
        stub(mockDustCalculator) { mock in
            when(mock.dust(type: any())).thenReturn(dust + 1)
        }

        do {
            let expectedFee = 100 + 10 + 2  // fee for tx + fee for change input + fee for change output
            let selectedOutputs = try unspentOutputSelector.select(value: 15000 - expectedFee, feeRate: 1, senderPay: true, pluginDataOutputSize: 0)
            XCTAssertEqual(selectedOutputs.unspentOutputs, [outputs[0], outputs[1], outputs[2], outputs[3]])
            XCTAssertEqual(selectedOutputs.recipientValue, 15000 - expectedFee)
            XCTAssertEqual(selectedOutputs.changeValue, nil)
        } catch {
            XCTFail("Unexpected error!")
        }
    }

    func testNotEnoughErrorReceiverPay() {
        do {
            _ = try unspentOutputSelector.select(value: 31001, feeRate: 1, senderPay: false, pluginDataOutputSize: 0)
            XCTFail("Wrong value summary!")
        } catch let error as BitcoinCoreErrors.SendValueErrors {
            XCTAssertEqual(error, BitcoinCoreErrors.SendValueErrors.notEnough)
        } catch {
            XCTFail("Unexpected \(error) error!")
        }
    }

    func testNotEnoughErrorSenderPay() {
        do {
            _ = try unspentOutputSelector.select(value: 30901, feeRate: 1, senderPay: true, pluginDataOutputSize: 0)
            XCTFail("Wrong value summary!")
        } catch let error as BitcoinCoreErrors.SendValueErrors {
            XCTAssertEqual(error, BitcoinCoreErrors.SendValueErrors.notEnough)
        } catch {
            XCTFail("Unexpected \(error) error!")
        }
    }

    func testEmptyOutputsError() {
        stub(mockUnspentOutputProvider) { mock in
            when(mock.spendableUtxo.get).thenReturn([])
        }
        do {
            _ = try unspentOutputSelector.select(value: 100, feeRate: 1, senderPay: false, pluginDataOutputSize: 0)
            XCTFail("Wrong value summary!")
        } catch let error as BitcoinCoreErrors.SendValueErrors {
            XCTAssertEqual(error, BitcoinCoreErrors.SendValueErrors.emptyOutputs)
        } catch {
            XCTFail("Unexpected \(error) error!")
        }
    }

}
