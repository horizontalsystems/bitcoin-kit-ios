import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class InputSignerTests: XCTestCase {

    private var mockHDWallet: MockIHDWallet!
    private var mockNetwork: MockINetwork!

    private var realm: Realm!
    private var transaction: Transaction!
    private var ownPubKey: PublicKey!
    private var inputSigner: InputSigner!

    override func setUp() {
        super.setUp()
        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }


        // Create private key/address provider for tests
        let privateKey = Data(hex: "4ee8efccaa04495d5d3ab0f847952fcff43ffc0459bd87981b6be485b92f8d64")!
        let publicKeyHash = Data(hex: "e4de5d630c5cacd7af96418a8f35c411c8ff3c06")!
        ownPubKey = PublicKey()
        ownPubKey.raw = Data(hex: "037d56797fbe9aa506fc263751abf23bb46c9770181a6059096808923f0a64cb15")!
        ownPubKey.keyHash = publicKeyHash

        let previousTransaction = TestData.p2pkhTransaction
        previousTransaction.outputs[0].publicKey = ownPubKey

        try! realm.write {
            realm.add(previousTransaction)
        }

        transaction = Transaction()
        transaction.version = 1
        let payInput = TestData.transactionInput(previousTransaction: previousTransaction, previousOutput: previousTransaction.outputs[0], script: Data(), sequence: 0)
        let payOutput = Output(withValue: 9, index: 0, lockingScript: Data(hex: "76a914e4de5d630c5cacd7af96418a8f35c411c8ff3c0688ac")!, type: .p2pkh, keyHash: Data())
        transaction.inputs.append(payInput)
        transaction.outputs.append(payOutput)

        mockHDWallet = MockIHDWallet()
        mockNetwork = MockINetwork()

        stub(mockHDWallet) { mock in
            when(mock.privateKeyData(account: any(), index: any(), external: any())).thenReturn(privateKey)
        }
        stub(mockNetwork) { mock in
            when(mock.sigHash.get).thenReturn(SigHashType.bitcoinAll)
        }

        inputSigner = InputSigner(hdWallet: mockHDWallet, network: mockNetwork)
    }

    override func tearDown() {
        realm = nil
        mockNetwork = nil
        mockHDWallet = nil
        inputSigner = nil
        transaction = nil

        super.tearDown()
    }

    func testCorrectSignature_P2PKH() {
        var resultSignature = [Data()]
        let signature = Data(hex: "3045022100a635a44b9565e9d8141c62217cebd2bf80cd6fc1a63bc3007942ead85c567d0b022027aa6e7cb692cce1604ce624299c8981e0ed22286e47ef64d58c16436bcb9add01")!

        do {
            resultSignature = try inputSigner.sigScriptData(transaction: transaction, index: 0)
        } catch {
            print(error)
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(resultSignature.count, 2)
        XCTAssertEqual(resultSignature[0], signature)
    }

    func testCorrectSignature_P2PK() {
        let previousTransaction = TestData.p2pkTransaction
        previousTransaction.outputs[0].publicKey = ownPubKey

        try! realm.write {
            realm.add(previousTransaction)
        }

        transaction = Transaction()
        transaction.version = 1
        let payInput = TestData.transactionInput(previousTransaction: previousTransaction, previousOutput: previousTransaction.outputs[0], script: Data(), sequence: 0)
        let payOutput = Output(withValue: 9, index: 0, lockingScript: Data(hex: "76a914e4de5d630c5cacd7af96418a8f35c411c8ff3c0688ac")!, type: .p2pkh, keyHash: Data())
        transaction.inputs.append(payInput)
        transaction.outputs.append(payOutput)


        var resultSignature = [Data()]
        let signature = Data(hex: "3045022100d247644e50ffbf8eaa33e7e530919a9c88a55f015bf86cb36010d06d9415055502207b6763939727b56460430f03857ae920371cab3dc3ba9e8971cfe7c19e096c2001")!

        do {
            resultSignature = try inputSigner.sigScriptData(transaction: transaction, index: 0)
        } catch {
            print(error)
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(resultSignature.count, 1)
        XCTAssertEqual(resultSignature[0], signature)
    }

    func testCorrectSignature_P2WPKH() {
        let previousTransaction = TestData.p2wpkhTransaction
        previousTransaction.outputs[0].publicKey = ownPubKey

        try! realm.write {
            realm.add(previousTransaction)
        }

        transaction = Transaction()
        transaction.version = 1
        let payInput = TestData.transactionInput(previousTransaction: previousTransaction, previousOutput: previousTransaction.outputs[0], script: Data(), sequence: 0)
        let payOutput = Output(withValue: 9, index: 0, lockingScript: Data(hex: "76a914e4de5d630c5cacd7af96418a8f35c411c8ff3c0688ac")!, type: .p2pkh, keyHash: Data())
        transaction.inputs.append(payInput)
        transaction.outputs.append(payOutput)


        var resultSignature = [Data()]
        let signature = Data(hex: "304402201c3b884a2ba6ee643036e9a3724132375e3aef0a56574dcae63c9ae408db26a5022049bc6b406ecff48a47cdf9830f6cdab6b95abb4021ee3f75e625a95b8624a99a01")!

        do {
            resultSignature = try inputSigner.sigScriptData(transaction: transaction, index: 0)
        } catch {
            print(error)
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(resultSignature.count, 2)
        XCTAssertEqual(resultSignature[0], signature)
    }

    func testNoPreviousOutput() {
        transaction.inputs[0].previousOutput = nil

        var caught = false
        do {
            let _ = try inputSigner.sigScriptData(transaction: transaction, index: 0)
        } catch let error as InputSigner.SignError {
            caught = true
            XCTAssertEqual(error, InputSigner.SignError.noPreviousOutput)
        } catch {
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(caught, true)
    }

    func testNoPreviousOutputAddress() {
        try! realm.write {
            realm.delete(ownPubKey)
        }

        var caught = false
        do {
            let _ = try inputSigner.sigScriptData(transaction: transaction, index: 0)
        } catch let error as InputSigner.SignError {
            caught = true
            XCTAssertEqual(error, InputSigner.SignError.noPreviousOutputAddress)
        } catch {
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(caught, true)
    }

    func testNoPrivateKey() {
        stub(mockHDWallet) { mock in
            when(mock.privateKeyData(account: any(), index: any(), external: any())).thenThrow(InputSigner.SignError.noPreviousOutputAddress)
        }

        var caught = false
        do {
            let _ = try inputSigner.sigScriptData(transaction: transaction, index: 0)
        } catch let error as InputSigner.SignError {
            caught = true
            XCTAssertEqual(error, InputSigner.SignError.noPrivateKey)
        } catch {
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(caught, true)
    }

}
