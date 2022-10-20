import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore

class Bip69Tests: QuickSpec {

    override func spec() {
        describe("sort two outputs") {

            it("sort by amount") {
                let outputWithBigAmount = Output(withValue: 140, index: 0, lockingScript: Data(), keyHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8))
                let outputWithSmallAmount = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8))

                let expected = [outputWithSmallAmount, outputWithBigAmount]
                let array = [outputWithBigAmount, outputWithSmallAmount]

                expect(expected).to(equal(array.sorted(by: Bip69.outputComparator)) )
            }

            it("amount are equal, sort by hashes") {
                let outputHashA = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8))
                let outputHashB = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "76a9145be32612930b8323add2212a4ec03c1562084f8488ac".data(using: .utf8))

                let expected = [outputHashA, outputHashB]
                let array = [outputHashA, outputHashB]

                expect(expected).to(equal(array.sorted(by: Bip69.outputComparator)) )
            }

            it("amount are equal, sort by hashes with different length") {
                let outputHashA = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8))
                let outputHashB = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "76a9144a5fba237213a062f6f57978f7".data(using: .utf8))

                let expected = [outputHashB, outputHashA]
                let array = [outputHashB, outputHashA]

                expect(expected).to(equal(array.sorted(by: Bip69.outputComparator)) )
            }

            it("sort by hashes") {
                let outputHashA = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "3d8ed454f4fcc03ba35568aa37528748e56c0142".data(using: .utf8))
                let outputHashB = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "e191794cbc83dfaabe399af396904dd22b721ce2".data(using: .utf8))

                let expected = [outputHashA, outputHashB]
                let array = [outputHashB, outputHashA]

                expect(expected).to(equal(array.sorted(by: Bip69.outputComparator)) )
            }

        }

        describe("sort two inputs") {

            it("sort by hash") {
                let unspentOutput1 = UnspentOutput(
                        output: Output(withValue: 0, index: 0, lockingScript: Data(), transactionHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8) ?? Data()), 
                        publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data()),
                        transaction: Transaction())
                let unspentOutput2 = UnspentOutput(
                        output: Output(withValue: 0, index: 0, lockingScript: Data(), transactionHash: "76a9145be32612930b8323add2212a4ec03c1562084f8488ac".data(using: .utf8) ?? Data()),
                        publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data()),
                        transaction: Transaction())

                let expected = [unspentOutput1, unspentOutput2]
                let array = [unspentOutput1, unspentOutput2]

                expect(expected).to(equal(array.sorted(by: Bip69.inputComparator)) )
            }

            it("sort by index") {
                let unspentOutput1 = UnspentOutput(
                        output: Output(withValue: 0, index: 1, lockingScript: Data(), transactionHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8) ?? Data()),
                        publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data()),
                        transaction: Transaction())
                let unspentOutput2 = UnspentOutput(
                        output: Output(withValue: 0, index: 1, lockingScript: Data(), transactionHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8) ?? Data()),
                        publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data()),
                        transaction: Transaction())

                let expected = [unspentOutput2, unspentOutput1]
                let array = [unspentOutput1, unspentOutput2]

                expect(expected).to(equal(array.sorted(by: Bip69.inputComparator)) )
            }

        }
    }

//    override func setUp() {
//        super.setUp()
//    }

//    override func tearDown() {
//        super.tearDown()
//    }

//    func testSortTwoOutputs() {
//        let outputWithBigAmount = Output(withValue: 140, index: 0, lockingScript: Data(), keyHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8))
//        let outputWithSmallAmount = Output(withValue: 12, index: 0, lockingScript: Data(), keyHash: "76a9144a5fba237213a062f6f57978f796390bdcf8d01588ac".data(using: .utf8))
//
//        let expected = [outputWithSmallAmount, outputWithBigAmount]
//        let array = [outputWithBigAmount, outputWithSmallAmount]
//        XCTAssertEqual(expected, array.sorted(by: Bip69.outputComparator))
//    }

//    func testParseBitcoinCashPaymentAddress() {
//        addressParser = PaymentAddressParser(validScheme: "bitcoincash", removeScheme: false)
//
//        var paymentData = BitcoinPaymentData(address: "address_data")
//        checkPaymentData(addressParser: addressParser, paymentAddress: "address_data", paymentData: paymentData)
//
//        // Check bitcoincash addresses parsing with keep scheme if it's valid
//        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data")
//        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data", paymentData: paymentData)
//
//        // invalid scheme - need to leave scheme
//        paymentData = BitcoinPaymentData(address: "bitcoin:address_data")
//        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:address_data", paymentData: paymentData)
//
//        // check parameters
//        paymentData = BitcoinPaymentData(address: "address_data", version: "1.0")
//        checkPaymentData(addressParser: addressParser, paymentAddress: "address_data;version=1.0", paymentData: paymentData)
//
//        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", version: "1.0", label: "test")
//        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data;version=1.0?label=test", paymentData: paymentData)
//
//        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", amount: 0.01)
//        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data?amount=0.01", paymentData: paymentData)
//
//        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", amount: 0.01, label: "test_sender")
//        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data?amount=0.01&label=test_sender", paymentData: paymentData)
//
//        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", parameters: ["custom":"any"])
//        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data?custom=any", paymentData: paymentData)
//    }

//    private func checkPaymentData(addressParser: PaymentAddressParser, paymentAddress: String, paymentData: BitcoinPaymentData) {
//        let bitcoinPaymentData = addressParser.parse(paymentAddress: paymentAddress)
//        XCTAssertEqual(bitcoinPaymentData, paymentData)
//    }

}
