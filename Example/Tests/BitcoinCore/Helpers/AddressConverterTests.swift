//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class AddressConverterTests: XCTestCase {
//    private var addressConverter: AddressConverterChain!
//    private var mockPaymentAddressParser: MockIPaymentAddressParser!
//    private var mockBech32: MockIBech32AddressConverter!
//
//    override func setUp() {
//        super.setUp()
//
//        let mockNetwork = MockINetwork()
//
//        stub(mockNetwork) { mock in
//            when(mock.pubKeyHash.get).thenReturn(0x6f)
//            when(mock.scriptHash.get).thenReturn(0xc4)
//            when(mock.pubKeyPrefixPattern.get).thenReturn("m|n")
//            when(mock.scriptPrefixPattern.get).thenReturn("2")
//            when(mock.bech32PrefixPattern.get).thenReturn("bc")
//        }
//        mockBech32 = MockIBech32AddressConverter()
//        stub(mockBech32) { mock in
//            when(mock.convert(prefix: any(), address: any())).thenThrow(AddressConverterChain.ConversionError.unknownAddressType)
//            when(mock.convert(prefix: any(), keyData: any(), scriptType: any())).thenThrow(AddressConverterChain.ConversionError.unknownAddressType)
//        }
//        mockPaymentAddressParser = MockIPaymentAddressParser()
//        addressConverter = AddressConverterChain(network: mockNetwork, bech32AddressConverter: mockBech32)
//    }
//
//    override func tearDown() {
//        addressConverter = nil
//        mockBech32 = nil
//
//        super.tearDown()
//    }
//
//    func testValidAddressConvert() {
//        let address = "msGCb97sW9s9Mt7gN5m7TGmwLqhqGaFqYz"
//        let keyHash = "80d733d7a4c02aba01da9370afc954c73a32dba5"
//        do {
//            let convertedData = try addressConverter.convert(address: address)
//            XCTAssertEqual(convertedData.keyHash, Data(hex: keyHash))
//        } catch {
//            XCTFail("Error Handled!")
//        }
//    }
//
//    func testValidPubKeyConvert() {
//        let address = "msGCb97sW9s9Mt7gN5m7TGmwLqhqGaFqYz"
//        let keyHash = "80d733d7a4c02aba01da9370afc954c73a32dba5"
//        do {
//            let convertedAddress = try addressConverter.convert(keyHash: Data(hex: keyHash)!, type: .p2pkh)
//            XCTAssertEqual(convertedAddress.stringValue, address)
//            XCTAssertEqual(convertedAddress.type, .pubKeyHash)
//        } catch {
//            XCTFail("Error Handled!")
//        }
//    }
//
//    func testValidSHAddressConvert() {
//        let address = "2NCRTejQCRReGuV4XpttwsMAxQTNRaYzrr1"
//        let keyHash = "D259F4688599C8422F477166A0C89344AD9EE72F"
//        do {
//            let convertedData = try addressConverter.convert(address: address)
//            XCTAssertEqual(convertedData.keyHash, Data(hex: keyHash))
//            XCTAssertEqual(convertedData.type, .scriptHash)
//        } catch {
//            XCTFail("Error Handled!")
//        }
//    }
//
//    func testValidSHKeyConvert() {
//        let address = "2NCRTejQCRReGuV4XpttwsMAxQTNRaYzrr1"
//        let keyHash = "D259F4688599C8422F477166A0C89344AD9EE72F"
//        do {
//            let convertedAddress = try addressConverter.convert(keyHash: Data(hex: keyHash)!, type: .p2sh)
//            XCTAssertEqual(convertedAddress.stringValue, address)
//        } catch {
//            XCTFail("Error Handled!")
//        }
//    }
//
//    func testAddressTooShort() {
//        let address = "2NCRTejQCRReGuV4XpttwsMAxQTNRaYzrr12NCRTejQCRReGuV4XpttwsMAxQTNRaYzrr1"
//
//        var caught = false
//        do {
//            let _ = try addressConverter.convert(address: address)
//        } catch let error as AddressConverterChain.ConversionError {
//            caught = true
//            XCTAssertEqual(error, AddressConverterChain.ConversionError.invalidAddressLength)
//        } catch {
//            XCTFail("Invalid Error thrown!")
//        }
//        XCTAssertEqual(caught, true)
//    }
//
//    func testAddressTooLong() {
//        let address = "2NCRTejQC"
//
//        do {
//            let _ = try addressConverter.convert(address: address)
//            XCTFail("No error thrown!")
//        } catch let error as AddressConverterChain.ConversionError {
//            XCTAssertEqual(error, AddressConverterChain.ConversionError.invalidAddressLength)
//        } catch {
//            XCTFail("Invalid Error thrown!")
//        }
//    }
//
//    func testInvalidChecksum() {
//        let address = "msGCb97sW9s9Mt7gN5m7TGmwLqhqGaFqYzz"
//
//        do {
//            let _ = try addressConverter.convert(address: address)
//            XCTFail("No error thrown!")
//        } catch let error as AddressConverterChain.ConversionError {
//            XCTAssertEqual(error, AddressConverterChain.ConversionError.invalidChecksum)
//        } catch {
//            XCTFail("Invalid Error thrown!")
//        }
//    }
//
//    func testUnknownAddressType() {
//        let keyHash = "80d733d7a4c02aba01da9370afc954c73a32dba5"
//
//        do {
//            let _ = try addressConverter.convert(keyHash: Data(hex: keyHash)!, type: .unknown)
//            XCTFail("No error thrown!")
//        } catch let error as AddressConverterChain.ConversionError {
//            XCTAssertEqual(error, AddressConverterChain.ConversionError.unknownAddressType)
//        } catch {
//            XCTFail("Invalid Error thrown!")
//        }
//    }
//
//    func testAddressPrefixWrong() {
//        let address = "3sGCb97sW9s9Mt7gN5m7TGmwLqhqGaFqYz"
//        do {
//            let _ = try addressConverter.convert(address: address)
//            XCTFail("No error handled!")
//        } catch let error as AddressConverterChain.ConversionError {
//            XCTAssertEqual(error, AddressConverterChain.ConversionError.wrongAddressPrefix)
//        } catch {
//            XCTFail("Invalid Error thrown!")
//        }
//    }
//
//}
