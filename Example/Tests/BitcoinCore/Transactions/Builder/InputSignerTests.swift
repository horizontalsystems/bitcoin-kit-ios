import XCTest
import Cuckoo
@testable import BitcoinCore

class InputSignerTests: XCTestCase {

    private var mockHDWallet: MockIHDWallet!
    private var mockNetwork: MockINetwork!

    private let publicKey = PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data(hex: "037d56797fbe9aa506fc263751abf23bb46c9770181a6059096808923f0a64cb15")!)
    private var inputSigner: InputSigner!

    override func setUp() {
        super.setUp()

        // Create private key/address provider for tests
        let privateKey = Data(hex: "4ee8efccaa04495d5d3ab0f847952fcff43ffc0459bd87981b6be485b92f8d64")!

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
        mockNetwork = nil
        mockHDWallet = nil
        inputSigner = nil

        super.tearDown()
    }

    func testCorrectSignature_P2PKH() {
        let previousTransaction = TestData.p2pkhTransaction
        let input = TestData.input(previousTransaction: previousTransaction.header, previousOutput: previousTransaction.outputs[0], script: Data(), sequence: 0)
        let inputToSign = InputToSign(input: input, previousOutput: previousTransaction.outputs[0], previousOutputPublicKey: publicKey)
        let output = Output(withValue: 9, index: 0, lockingScript: Data(hex: "76a914e4de5d630c5cacd7af96418a8f35c411c8ff3c0688ac")!, type: .p2pkh, keyHash: Data())
        let transaction = Transaction(version: 1, lockTime: 0, timestamp: 0)

        var resultSignature = [Data()]

        do {
            resultSignature = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: [inputToSign], outputs: [output], index: 0)
        } catch {
            print(error)
            XCTFail("Unexpected error")
        }

        let signature = Data(hex: "3045022100d845739e4f2355acf785e4f379d736cd4aa303e2613f168a9248e3147a5cf376022045b876d3274a8fb43a80c7866d0790d10537798a49709e035e6fbea054ff277b01")!
        XCTAssertEqual(resultSignature.count, 2)
        XCTAssertEqual(resultSignature[0], signature)
        XCTAssertEqual(resultSignature[1], publicKey.raw)
    }

    func testCorrectSignature_P2PK() {
        let previousTransaction = TestData.p2pkTransaction
        let input = TestData.input(previousTransaction: previousTransaction.header, previousOutput: previousTransaction.outputs[0], script: Data(), sequence: 0)
        let inputToSign = InputToSign(input: input, previousOutput: previousTransaction.outputs[0], previousOutputPublicKey: publicKey)
        let output = Output(withValue: 9, index: 0, lockingScript: Data(hex: "76a914e4de5d630c5cacd7af96418a8f35c411c8ff3c0688ac")!, type: .p2pkh, keyHash: Data())
        let transaction = Transaction(version: 1, lockTime: 0, timestamp: 0)

        var resultSignature = [Data()]
        let signature = Data(hex: "3045022100d247644e50ffbf8eaa33e7e530919a9c88a55f015bf86cb36010d06d9415055502207b6763939727b56460430f03857ae920371cab3dc3ba9e8971cfe7c19e096c2001")!

        do {
            resultSignature = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: [inputToSign], outputs: [output], index: 0)
        } catch {
            print(error)
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(resultSignature.count, 1)
        XCTAssertEqual(resultSignature[0], signature)
    }

    func testCorrectSignature_P2WPKH() {
        let previousTransaction = TestData.p2wpkhTransaction
        let input = TestData.input(previousTransaction: previousTransaction.header, previousOutput: previousTransaction.outputs[0], script: Data(), sequence: 0)
        let inputToSign = InputToSign(input: input, previousOutput: previousTransaction.outputs[0], previousOutputPublicKey: publicKey)
        let output = Output(withValue: 9, index: 0, lockingScript: Data(hex: "76a914e4de5d630c5cacd7af96418a8f35c411c8ff3c0688ac")!, type: .p2pkh, keyHash: Data())
        let transaction = Transaction(version: 1, lockTime: 0, timestamp: 0)

        var resultSignature = [Data()]
        let signature = Data(hex: "304402201c3b884a2ba6ee643036e9a3724132375e3aef0a56574dcae63c9ae408db26a5022049bc6b406ecff48a47cdf9830f6cdab6b95abb4021ee3f75e625a95b8624a99a01")!

        do {
            resultSignature = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: [inputToSign], outputs: [output], index: 0)
        } catch {
            print(error)
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(resultSignature.count, 2)
        XCTAssertEqual(resultSignature[0], signature)
        XCTAssertEqual(resultSignature[1], publicKey.raw)
    }

    func testNoPrivateKey() {
        stub(mockHDWallet) { mock in
            when(mock.privateKeyData(account: any(), index: any(), external: any())).thenThrow(InputSigner.SignError.noPreviousOutputAddress)
        }

        let previousTransaction = TestData.p2wpkhTransaction
        let input = TestData.input(previousTransaction: previousTransaction.header, previousOutput: previousTransaction.outputs[0], script: Data(), sequence: 0)
        let inputToSign = InputToSign(input: input, previousOutput: previousTransaction.outputs[0], previousOutputPublicKey: publicKey)
        let output = Output(withValue: 9, index: 0, lockingScript: Data(hex: "76a914e4de5d630c5cacd7af96418a8f35c411c8ff3c0688ac")!, type: .p2pkh, keyHash: Data())
        let transaction = Transaction(version: 1, lockTime: 0, timestamp: 0)


        var caught = false
        do {
            _ = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: [inputToSign], outputs: [output], index: 0)
        } catch let error as InputSigner.SignError {
            caught = true
            XCTAssertEqual(error, InputSigner.SignError.noPrivateKey)
        } catch {
            XCTFail("Unexpected error")
        }

        XCTAssertEqual(caught, true)
    }

}
