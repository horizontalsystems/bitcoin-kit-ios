import XCTest
import Cuckoo
@testable import BitcoinCore

class TransactionLinkerTests: XCTestCase {

    private var mockStorage: MockIStorage!

    private var previousOutput: Output!
    private var pubKeyHash = Data(hex: "1ec865abcb88cec71c484d4dadec3d7dc0271a7b")!

    private var linker: TransactionLinker!

    override func setUp() {
        super.setUp()

        mockStorage = MockIStorage()
        linker = TransactionLinker(storage: mockStorage)
        previousOutput = TestData.p2pkhTransaction.outputs[0]
    }

    override func tearDown() {
        mockStorage = nil
        linker = nil
        previousOutput = nil

        super.tearDown()
    }

    func testHandle_HasPreviousOutput() {
        previousOutput.publicKeyPath = TestData.pubKey().path
        let input = Input(withPreviousOutputTxHash: previousOutput.transactionHash, previousOutputIndex: previousOutput.index, script: Data(), sequence: 100)
        let fullTransaction = FullTransaction(header: Transaction(), inputs: [input], outputs: [])

        stub(mockStorage) { mock in
            when(mock.previousOutput(ofInput: equal(to: input))).thenReturn(previousOutput)
            when(mock.publicKey(byPath: equal(to: previousOutput.publicKeyPath!))).thenReturn(TestData.pubKey())
        }

        linker.handle(transaction: fullTransaction)

        XCTAssertEqual(fullTransaction.header.isMine, true)
        XCTAssertEqual(fullTransaction.header.isOutgoing, true)
    }

    func testHandle_HasPreviousOutputWhichIsNotMine() {
        let input = Input(withPreviousOutputTxHash: previousOutput.transactionHash, previousOutputIndex: previousOutput.index, script: Data(), sequence: 100)
        let fullTransaction = FullTransaction(header: Transaction(), inputs: [input], outputs: [])

        stub(mockStorage) { mock in
            when(mock.previousOutput(ofInput: equal(to: input))).thenReturn(previousOutput)
        }

        linker.handle(transaction: fullTransaction)

        XCTAssertEqual(fullTransaction.header.isMine, false)
        XCTAssertEqual(fullTransaction.header.isOutgoing, false)
    }

    func testHandle_HasNotPreviousOutput() {
        let input = Input(withPreviousOutputTxHash: previousOutput.transactionHash, previousOutputIndex: previousOutput.index, script: Data(), sequence: 100)
        let fullTransaction = FullTransaction(header: Transaction(), inputs: [input], outputs: [])

        stub(mockStorage) { mock in
            when(mock.previousOutput(ofInput: equal(to: input))).thenReturn(nil)
        }

        linker.handle(transaction: fullTransaction)

        XCTAssertEqual(fullTransaction.header.isMine, false)
        XCTAssertEqual(fullTransaction.header.isOutgoing, false)
    }

    private func assertOutputEqual(out1: Output, out2: Output) {
        XCTAssertEqual(out1.value, out2.value)
        XCTAssertEqual(out1.lockingScript, out2.lockingScript)
        XCTAssertEqual(out1.index, out2.index)
    }

}
