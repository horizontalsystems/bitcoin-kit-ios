import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionCreatorTests: XCTestCase {

    private var realm: Realm!
    private var mockTransactionBuilder: MockTransactionBuilder!
    private var mockTransactionProcessor: MockTransactionProcessor!
    private var mockPeerGroup: MockPeerGroup!
    private var mockAddressManager: MockAddressManager!

    private var transactionCreator: TransactionCreator!

    override func setUp() {
        super.setUp()

        let mockBitcoinKit = MockBitcoinKit()

        realm = mockBitcoinKit.realm

        mockTransactionBuilder = mockBitcoinKit.mockTransactionBuilder
        mockTransactionProcessor = mockBitcoinKit.mockTransactionProcessor
        mockPeerGroup = mockBitcoinKit.mockPeerGroup
        mockAddressManager = mockBitcoinKit.mockAddressManager

        stub(mockTransactionBuilder) { mock in
            when(mock.buildTransaction(value: any(), feeRate: any(), senderPay: any(), changeScriptType: any(), changePubKey: any(), toAddress: any())).thenReturn(TestData.p2pkhTransaction)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.enqueueRun()).thenDoNothing()
        }
        stub(mockPeerGroup) { mock in
            when(mock.send(transaction: any())).thenDoNothing()
        }
        stub(mockAddressManager) { mock in
            when(mock.changePublicKey()).thenReturn(TestData.pubKey())
        }

        transactionCreator = TransactionCreator(realmFactory: mockBitcoinKit.mockRealmFactory, transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, peerGroup: mockPeerGroup, addressManager: mockAddressManager)
    }

    override func tearDown() {
        realm = nil
        mockTransactionBuilder = nil
        mockTransactionProcessor = nil
        mockPeerGroup = nil
        mockAddressManager = nil
        transactionCreator = nil

        super.tearDown()
    }

    func testCreateTransaction() {
        try! transactionCreator.create(to: "Address", value: 1)

        guard let transaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", TestData.p2pkhTransaction.reversedHashHex).first else {
            XCTFail("No transaction record!")
            return
        }

        verify(mockPeerGroup).send(transaction: equal(to: transaction))
        verify(mockTransactionProcessor).enqueueRun()
    }

    func testNoChangeAddress() {
        stub(mockAddressManager) { mock in
            when(mock.changePublicKey()).thenThrow(TransactionBuilder.BuildError.feeMoreThanValue)
        }

        do {
            try transactionCreator.create(to: "Address", value: 1)
            XCTFail("No exception!")
        } catch let error as TransactionCreator.CreationError {
            XCTAssertEqual(error, TransactionCreator.CreationError.noChangeAddress)
        } catch {
            XCTFail("Unexpected exception!")
        }

        verify(mockPeerGroup, never()).send(transaction: any())
        verify(mockTransactionProcessor, never()).enqueueRun()
    }

}
