import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionBuilderTests: XCTestCase {

    private var realm: Realm!
    private var mockUnspentOutputSelector: MockIUnspentOutputSelector!
    private var mockUnspentOutputProvider: MockIUnspentOutputProvider!
    private var mockAddressManager: MockIAddressManager!
    private var mockAddressConverter: MockIAddressConverter!
    private var mockInputSigner: MockIInputSigner!
    private var mockScriptBuilder: MockIScriptBuilder!
    private var mockFactory: MockIFactory!

    private var transactionBuilder: TransactionBuilder!

    private var unspentOutputs: SelectedUnspentOutputInfo!
    private var previousTransaction: Transaction!
    private var transaction: Transaction!
    private var toOutputPKH: TransactionOutput!
    private var toOutputWPKH: TransactionOutput!
    private var toOutputSH: TransactionOutput!
    private var changeOutput: TransactionOutput!
    private var input: TransactionInput!
    private var totalInputValue: Int!
    private var value: Int!
    private var feeRate: Int!
    private var fee: Int!
    private var changePubKey: PublicKey!
    private var changePubKeyAddress: String!
    private var toAdressPKH: String!
    private var toAddressSH: String!
    private var toAddressWPKH: String!
    private var signature = Data(hex: "0000000000000000000111111111111222222222222")!
    private var signatureScript = Data(hex: "aaaaaaaaaa0000000000000000000111111111111222222222222")!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        mockUnspentOutputSelector = MockIUnspentOutputSelector()
        mockUnspentOutputProvider = MockIUnspentOutputProvider()
        mockAddressManager = MockIAddressManager()
        mockAddressConverter = MockIAddressConverter()
        mockInputSigner = MockIInputSigner()
        mockScriptBuilder = MockIScriptBuilder()
        mockFactory = MockIFactory()

        transactionBuilder = TransactionBuilder(unspentOutputSelector: mockUnspentOutputSelector, unspentOutputProvider: mockUnspentOutputProvider, addressManager: mockAddressManager, addressConverter: mockAddressConverter, inputSigner: mockInputSigner, scriptBuilder: mockScriptBuilder, factory: mockFactory)

        changePubKey = TestData.pubKey()
        changePubKeyAddress = "Rsfz3aRmCwTe2J8pSWSYRNYmweJ"

        toAdressPKH = "mzwSXvtPs7MFbW2ysNA4Gw3P2KjrcEWaE5"
        toAddressSH = "2MyQWMrsLsqAMSUeusduAzN6pWuH2V27ykE"
        toAddressWPKH = "bcrt1qsay3z5rn44v6du6c0u0eu352mm0sz3el0f0cs2"

        previousTransaction = TestData.p2pkhTransaction
        try! realm.write {
            realm.add(previousTransaction)
        }

        unspentOutputs = SelectedUnspentOutputInfo(outputs: [previousTransaction.outputs[0]], totalValue: previousTransaction.outputs[0].value, fee: 1008, addChangeOutput: true)
        totalInputValue = unspentOutputs.outputs[0].value
        value = 10782000
        feeRate = 6
        fee = 1008

        transaction = Transaction(version: 1, inputs: [], outputs: [])
        input = TransactionInput(withPreviousOutputTxReversedHex: previousTransaction.reversedHashHex, previousOutputIndex: unspentOutputs.outputs[0].index, script: Data(), sequence: 0)
        toOutputPKH = TransactionOutput(withValue: value - fee, index: 0, lockingScript: Data(), type: .p2pkh, address: toAdressPKH, keyHash: nil)
        toOutputWPKH = TransactionOutput(withValue: value - fee, index: 0, lockingScript: Data(), type: .p2wpkh, address: toAddressWPKH, keyHash: nil)
        toOutputSH = TransactionOutput(withValue: value - fee, index: 0, lockingScript: Data(), type: .p2sh, address: toAddressSH, keyHash: nil)
        changeOutput = TransactionOutput(withValue: totalInputValue - value, index: 1, lockingScript: Data(), type: .p2pkh, keyHash: changePubKey.keyHash)

        stub(mockUnspentOutputSelector) { mock in
            when(mock.select(value: any(), feeRate: any(), outputScriptType: any(), changeType: any(), senderPay: any(), outputs: any())).thenReturn(unspentOutputs)
        }

        stub(mockUnspentOutputProvider) { mock in
            when(mock.allUnspentOutputs()).thenReturn(unspentOutputs.outputs)
        }

        stub(mockAddressManager) { mock in
            when(mock.changePublicKey()).thenReturn(changePubKey)
        }

        stub(mockInputSigner) { mock in
            when(mock.sigScriptData(transaction: any(), index: any())).thenReturn([signature])
        }

        stub(mockAddressConverter) { mock in
            when(mock.convert(address: toAdressPKH)).thenReturn(LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "d50bf226c9ff3bcf06f13d8ca129f24bedeef594")!, base58: "mzwSXvtPs7MFbW2ysNA4Gw3P2KjrcEWaE5"))
            when(mock.convert(address: toAddressSH)).thenReturn(LegacyAddress(type: .scriptHash, keyHash: Data(hex: "43922a3f1dc4569f9eccce9a71549d5acabbc0ca")!, base58: toAddressSH))
            when(mock.convert(address: toAddressWPKH)).thenReturn(SegWitAddress(type: .pubKeyHash, keyHash: Data(hex: "43922a3f1dc4569f9eccce9a71549d5acabbc0ca")!, bech32: "bcrt1qsay3z5rn44v6du6c0u0eu352mm0sz3el0f0cs2", version: 0))
            when(mock.convert(address: changePubKeyAddress)).thenReturn(LegacyAddress(type: .pubKeyHash, keyHash: changePubKey.keyHash, base58: changePubKeyAddress))
            when(mock.convert(keyHash: equal(to: changePubKey.keyHash), type: equal(to: .p2pkh))).thenReturn(LegacyAddress(type: .pubKeyHash, keyHash: changePubKey.keyHash, base58: changePubKeyAddress))
            //            when(mock.convert(address: any())).thenReturn(Address(type: .pubKeyHash, keyHash: Data(), base58: ""))
        }

        stub(mockScriptBuilder) { mock in
            when(mock.lockingScript(for: any())).thenReturn(Data())
            when(mock.unlockingScript(params: any())).thenReturn(signatureScript)
        }

        stub(mockFactory) { mock in
            when(mock.transaction(version: any(), inputs: any(), outputs: any(), lockTime: any())).thenReturn(transaction)
        }

        stub(mockFactory) { mock in
            when(mock.transactionInput(withPreviousOutputTxReversedHex: any(), previousOutputIndex: any(), script: any(), sequence: any())).thenReturn(input)
        }

        stub(mockFactory) { mock in
            when(mock.transactionOutput(withValue: any(), index: any(), lockingScript: any(), type: equal(to: ScriptType.p2pkh), address: equal(to: toAdressPKH), keyHash: any(), publicKey: any())).thenReturn(toOutputPKH)
            when(mock.transactionOutput(withValue: any(), index: any(), lockingScript: any(), type: equal(to: ScriptType.p2sh), address: equal(to: toAddressSH), keyHash: any(), publicKey: any())).thenReturn(toOutputSH)
            when(mock.transactionOutput(withValue: any(), index: any(), lockingScript: any(), type: equal(to: ScriptType.p2wpkh), address: equal(to: toAddressWPKH), keyHash: any(), publicKey: any())).thenReturn(toOutputWPKH)
            when(mock.transactionOutput(withValue: any(), index: any(), lockingScript: any(), type: equal(to: ScriptType.p2pkh), address: equal(to: changePubKeyAddress), keyHash: any(), publicKey: any())).thenReturn(changeOutput)
        }
    }

    override func tearDown() {
        realm = nil
        unspentOutputs = nil
        mockUnspentOutputSelector = nil
        mockUnspentOutputProvider = nil
        mockAddressConverter = nil
        mockInputSigner = nil
        mockFactory = nil
        transactionBuilder = nil
        changePubKey = nil
        toAdressPKH = nil
        toAddressSH = nil
        value = nil
        feeRate = nil
        fee = nil

        super.tearDown()
    }

    func testFee_AddressGiven() {
        let resultFee = try! transactionBuilder.fee(for: value, feeRate: feeRate, senderPay: false, address: toAdressPKH)
        XCTAssertEqual(resultFee, 570)
    }

    func testFee_AddressGiven_Error() {
        stub(mockAddressConverter) { mock in
            when(mock.convert(address: toAdressPKH)).thenThrow(AddressConverter.ConversionError.invalidAddressLength)
        }

        do {
            let _ = try transactionBuilder.fee(for: value, feeRate: feeRate, senderPay: false, address: toAdressPKH)
        } catch let error as AddressConverter.ConversionError {
            XCTAssertEqual(error, AddressConverter.ConversionError.invalidAddressLength)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }

    func testFee_AddressNotGiven_Error() {
        let resultFee = try! transactionBuilder.fee(for: value, feeRate: feeRate, senderPay: false)
        XCTAssertEqual(resultFee, fee)
    }

    func testBuildTransaction_P2PKH() {
        let resultTx = try! transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAdressPKH)

        XCTAssertNotEqual(resultTx.reversedHashHex, "")
        XCTAssertEqual(resultTx.status, .new)
        XCTAssertEqual(resultTx.isMine, true)
        XCTAssertEqual(resultTx.segWit, false)
        XCTAssertEqual(resultTx.inputs.count, 1)
        XCTAssertEqual(resultTx.inputs[0].signatureScript, signatureScript)
        XCTAssertEqual(resultTx.inputs[0].witnessData.count, 0)
        XCTAssertEqual(resultTx.inputs[0].previousOutput!, unspentOutputs.outputs[0])
        XCTAssertEqual(resultTx.outputs.count, 2)
        XCTAssertEqual(resultTx.outputs[0].address, toAdressPKH)
        XCTAssertEqual(resultTx.outputs[0].value, value - fee)  // value - fee
        XCTAssertEqual(resultTx.outputs[1].keyHash, changePubKey.keyHash)
        XCTAssertEqual(resultTx.outputs[1].value, unspentOutputs.outputs[0].value - value)
    }

    func testBuildTransaction_P2WPKH() {
        let previousTransaction = TestData.p2wpkhTransaction
        try! realm.write {
            realm.add(previousTransaction)
        }

        unspentOutputs = SelectedUnspentOutputInfo(outputs: [previousTransaction.outputs[0]], totalValue: previousTransaction.outputs[0].value, fee: 1008, addChangeOutput: true)
        totalInputValue = unspentOutputs.outputs[0].value
        value = 10782000
        feeRate = 6
        fee = 1008

        stub(mockUnspentOutputSelector) { mock in
            when(mock.select(value: any(), feeRate: any(), outputScriptType: any(), changeType: any(), senderPay: any(), outputs: any())).thenReturn(unspentOutputs)
        }

        stub(mockUnspentOutputProvider) { mock in
            when(mock.allUnspentOutputs()).thenReturn(unspentOutputs.outputs)
        }

        let resultTx = try! transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAddressWPKH)

        XCTAssertNotEqual(resultTx.reversedHashHex, "")
        XCTAssertEqual(resultTx.status, .new)
        XCTAssertEqual(resultTx.isMine, true)
        XCTAssertEqual(resultTx.segWit, true)
        XCTAssertEqual(resultTx.inputs.count, 1)
        XCTAssertEqual(resultTx.inputs[0].signatureScript.count, 0)
        XCTAssertEqual(resultTx.inputs[0].witnessData.count, 1)
        XCTAssertEqual(resultTx.inputs[0].witnessData[0], signature)
        XCTAssertEqual(resultTx.inputs[0].previousOutput!, unspentOutputs.outputs[0])
        XCTAssertEqual(resultTx.outputs.count, 2)
        XCTAssertEqual(resultTx.outputs[0].address, toAddressWPKH)
        XCTAssertEqual(resultTx.outputs[0].value, value - fee)  // value - fee
        XCTAssertEqual(resultTx.outputs[1].keyHash, changePubKey.keyHash)
        XCTAssertEqual(resultTx.outputs[1].value, unspentOutputs.outputs[0].value - value)
    }

    func testBuildTransaction_P2SH() {
        let resultTx = try! transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAddressSH)

        XCTAssertNotEqual(resultTx.reversedHashHex, "")
        XCTAssertEqual(resultTx.status, .new)
        XCTAssertEqual(resultTx.isMine, true)
        XCTAssertEqual(resultTx.inputs.count, 1)
        XCTAssertEqual(resultTx.inputs[0].previousOutput!, unspentOutputs.outputs[0])
        XCTAssertEqual(resultTx.outputs.count, 2)
        XCTAssertEqual(resultTx.outputs[0].address, toAddressSH)
        XCTAssertEqual(resultTx.outputs[0].value, value - fee)  // value - fee
        XCTAssertEqual(resultTx.outputs[1].keyHash, changePubKey.keyHash)
        XCTAssertEqual(resultTx.outputs[1].value, unspentOutputs.outputs[0].value - value)
    }

    func testBuildTransactionSenderPay() {
        let resultTx = try! transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: true, toAddress: toAdressPKH)

        XCTAssertEqual(resultTx.outputs[0].value, value)  // value - fee
        verify(mockFactory).transactionOutput(withValue: unspentOutputs.outputs[0].value - value - fee, index: 1, lockingScript: any(), type: equal(to: ScriptType.p2pkh), address: equal(to: changePubKeyAddress), keyHash: any(), publicKey: any())
    }

    func testBuildTransaction_WithoutChangeOutput() {
        value = totalInputValue
        unspentOutputs = SelectedUnspentOutputInfo(outputs: unspentOutputs.outputs, totalValue: unspentOutputs.totalValue, fee: unspentOutputs.fee, addChangeOutput: false)
        stub(mockUnspentOutputSelector) { mock in
            when(mock.select(value: any(), feeRate: any(), outputScriptType: any(), changeType: any(), senderPay: any(), outputs: any())).thenReturn(unspentOutputs)
        }

        let resultTx = try! transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAdressPKH)

        XCTAssertEqual(resultTx.inputs.count, 1)
        XCTAssertEqual(resultTx.inputs[0].previousOutput!, unspentOutputs.outputs[0])
        XCTAssertEqual(resultTx.outputs.count, 1)
        XCTAssertEqual(resultTx.outputs[0].address, toAdressPKH)
        XCTAssertEqual(resultTx.outputs[0].value, value - fee)
    }

    func testBuildTransaction_ChangeNotAddedForDust() {
        value = totalInputValue - TransactionSizeCalculator().outputSize(type: .p2pkh) * feeRate
        unspentOutputs = SelectedUnspentOutputInfo(outputs: unspentOutputs.outputs, totalValue: unspentOutputs.totalValue, fee: unspentOutputs.fee, addChangeOutput: false)
        stub(mockUnspentOutputSelector) { mock in
            when(mock.select(value: any(), feeRate: any(), outputScriptType: any(), changeType: any(), senderPay: any(), outputs: any())).thenReturn(unspentOutputs)
        }

        let resultTx = try! transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAdressPKH)

        XCTAssertEqual(resultTx.inputs.count, 1)
        XCTAssertEqual(resultTx.inputs[0].previousOutput!, unspentOutputs.outputs[0])
        XCTAssertEqual(resultTx.outputs.count, 1)
        XCTAssertEqual(resultTx.outputs[0].address, toAdressPKH)
        XCTAssertEqual(resultTx.outputs[0].value, value - fee)
    }

    func testBuildTransaction_InputsSigned() {
        let sigData = [Data(hex: "000001")!, Data(hex: "000002")!]
        let sigScript = Data(hex: "000001000002")!

        stub(mockInputSigner) { mock in
            when(mock.sigScriptData(transaction: any(), index: any())).thenReturn(sigData)
        }

        stub(mockScriptBuilder) { mock in
            when(mock.unlockingScript(params: any())).thenReturn(sigScript)
        }

        let resultTx = try! transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAdressPKH)
        XCTAssertEqual(resultTx.inputs[0].signatureScript, sigScript)
    }

    func testBuildTransaction_feeMoreThanValue() {
        unspentOutputs = SelectedUnspentOutputInfo(outputs: [previousTransaction.outputs[0]], totalValue: previousTransaction.outputs[0].value, fee: value, addChangeOutput: true)

        do {
            let _ = try transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAdressPKH)
        } catch let error as TransactionBuilder.BuildError {
            XCTAssertEqual(error, TransactionBuilder.BuildError.feeMoreThanValue)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }

    func testBuildTransaction_noPreviousTransaction() {
        try! realm.write {
            previousTransaction.outputs[0].scriptType = .p2wpkhSh
            previousTransaction.outputs[0].publicKey = nil
        }

        do {
            let _ = try transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAdressPKH)
        } catch let error as TransactionBuilder.BuildError {
            XCTAssertEqual(error, TransactionBuilder.BuildError.noPreviousTransaction)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }

    func testBuildTransaction_noChangeAddress() {
        stub(mockAddressManager) { mock in
            when(mock.changePublicKey()).thenThrow(AddressManager.AddressManagerError.noUnusedPublicKey)
        }

        do {
            let _ = try transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: false, toAddress: toAdressPKH)
            XCTFail("No exception!")
        } catch let error as TransactionBuilder.BuildError {
            XCTAssertEqual(error, TransactionBuilder.BuildError.noChangeAddress)
        } catch {
            XCTFail("Unexpected exception!")
        }
    }

}
