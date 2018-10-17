import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class TransactionLinkerTests: XCTestCase {

    private var linker: TransactionLinker!

    private var realm: Realm!
    private var transaction: Transaction!
    private var pubKey: PublicKey!
    private var pubKeys: Results<PublicKey>!
    private var pubKeyHash = Data(hex: "1ec865abcb88cec71c484d4dadec3d7dc0271a7b")!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        realm = mockWalletKit.realm

        linker = TransactionLinker()
        transaction = TestData.p2pkhTransaction
        pubKey = TestData.pubKey(pubKeyHash: pubKeyHash)

        try! realm.write {
            realm.add(pubKey, update: true)
            realm.add(transaction)
        }

        pubKeys = realm.objects(PublicKey.self)
    }

    override func tearDown() {
        linker = nil
        realm = nil

        super.tearDown()
    }

    func testLinkInputs() {
        let input = TransactionInput()
        input.previousOutputTxReversedHex = transaction.reversedHashHex
        input.previousOutputIndex = transaction.outputs.first!.index
        input.sequence = 100

        let savedNextTransaction = Transaction()
        savedNextTransaction.reversedHashHex = "0000000000000000000111111111111122222222222222333333333333333000"
        savedNextTransaction.inputs.append(input)

        try! realm.write {
            realm.add(transaction, update: true)
            realm.add(savedNextTransaction, update: true)
        }

        XCTAssertEqual(savedNextTransaction.inputs.first!.previousOutput, nil)
        try? realm.write {
            linker.handle(transaction: savedNextTransaction, realm: realm)
        }
        assertOutputEqual(out1: savedNextTransaction.inputs.first!.previousOutput!, out2: transaction.outputs.first!)
    }

    func testSetTransactionIsMine_ByPrevious() {
        let output = TransactionOutput()
        output.index = transaction.inputs[0].previousOutputIndex
        output.value = 100000
        output.publicKey = pubKey

        let savedPreviousTransaction = Transaction()
        savedPreviousTransaction.reversedHashHex = transaction.inputs[0].previousOutputTxReversedHex
        savedPreviousTransaction.outputs.append(output)

        try! realm.write {
            realm.add(transaction, update: true)
            realm.add(savedPreviousTransaction, update: true)
        }

        XCTAssertEqual(transaction.isMine, false)
        try? realm.write {
            linker.handle(transaction: transaction, realm: realm)
        }
        XCTAssertEqual(transaction.isMine, true)
    }

    private func assertOutputEqual(out1: TransactionOutput, out2: TransactionOutput) {
        XCTAssertEqual(out1.value, out2.value)
        XCTAssertEqual(out1.lockingScript, out2.lockingScript)
        XCTAssertEqual(out1.index, out2.index)
    }

}
