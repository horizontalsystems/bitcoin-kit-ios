import XCTest
import Cuckoo
@testable import BitcoinCore

class PaymentAddressParserTests: XCTestCase {

    private var addressParser: PaymentAddressParser!

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        addressParser = nil

        super.tearDown()
    }

    func testParseBitcoinPaymentAddress() {
        addressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)

        var paymentData = BitcoinPaymentData(address: "address_data")
        checkPaymentData(addressParser: addressParser, paymentAddress: "address_data", paymentData: paymentData)

        // Check bitcoin addresses parsing with drop scheme if it's valid
        paymentData = BitcoinPaymentData(address: "address_data")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:address_data", paymentData: paymentData)

        // invalid scheme - need to keep scheme
        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data", paymentData: paymentData)

        // check parameters
        paymentData = BitcoinPaymentData(address: "address_data", version: "1.0")
        checkPaymentData(addressParser: addressParser, paymentAddress: "address_data;version=1.0", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "address_data", version: "1.0", label: "test")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:address_data;version=1.0?label=test", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "address_data", amount: 0.01)
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:address_data?amount=0.01", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "address_data", amount: 0.01, label: "test_sender")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:address_data?amount=0.01&label=test_sender", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "address_data", parameters: ["custom":"any"])
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:address_data?custom=any", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W", amount: 50, label: "Luke-Jr", message: "Donation for project xyz")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?amount=50&label=Luke-Jr&message=Donation%20for%20project%20xyz", paymentData: paymentData)
    }

    func testParseBitcoinCashPaymentAddress() {
        addressParser = PaymentAddressParser(validScheme: "bitcoincash", removeScheme: false)

        var paymentData = BitcoinPaymentData(address: "address_data")
        checkPaymentData(addressParser: addressParser, paymentAddress: "address_data", paymentData: paymentData)

        // Check bitcoincash addresses parsing with keep scheme if it's valid
        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data", paymentData: paymentData)

        // invalid scheme - need to leave scheme
        paymentData = BitcoinPaymentData(address: "bitcoin:address_data")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoin:address_data", paymentData: paymentData)

        // check parameters
        paymentData = BitcoinPaymentData(address: "address_data", version: "1.0")
        checkPaymentData(addressParser: addressParser, paymentAddress: "address_data;version=1.0", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", version: "1.0", label: "test")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data;version=1.0?label=test", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", amount: 0.01)
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data?amount=0.01", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", amount: 0.01, label: "test_sender")
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data?amount=0.01&label=test_sender", paymentData: paymentData)

        paymentData = BitcoinPaymentData(address: "bitcoincash:address_data", parameters: ["custom":"any"])
        checkPaymentData(addressParser: addressParser, paymentAddress: "bitcoincash:address_data?custom=any", paymentData: paymentData)
    }

    private func checkPaymentData(addressParser: PaymentAddressParser, paymentAddress: String, paymentData: BitcoinPaymentData) {
        let bitcoinPaymentData = addressParser.parse(paymentAddress: paymentAddress)
        XCTAssertEqual(bitcoinPaymentData, paymentData)
    }

}
