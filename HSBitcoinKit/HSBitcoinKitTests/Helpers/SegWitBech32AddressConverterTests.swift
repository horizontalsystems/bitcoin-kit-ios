import XCTest
import Cuckoo
@testable import HSBitcoinKit

class SegWitBech32AddressConverterTests: XCTestCase {
    private var segWitBech32Converter: SegWitBech32AddressConverter!

    override func setUp() {
        super.setUp()
        segWitBech32Converter = SegWitBech32AddressConverter()
    }

    override func tearDown() {
        segWitBech32Converter = nil

        super.tearDown()
    }

    func testAll() {
        // invalid strings
        // empty string
        checkError(prefix: "bc", address: "")
        checkError(prefix: "bc", address: " ")
        // invalid upper and lower case at the same time "Q" "zdvr2hn0xrz99fcp6hkjxzk848rjvvhgytv4fket8"
        checkError(prefix: "bc", address: "bc1Qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4")
        // HRP character out of range
        checkError(prefix: "bc", address: "\(String(0x20))1nwldj5")
        checkError(prefix: "bc", address: "\(String(0x7F))1axkwrx")
        // overall max length exceeded
        checkError(prefix: "an84characterslonghumanreadablepartthatcontainsthenumber", address: "an84characterslonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1569pvx")
        // Invalid data character
        checkError(prefix: "x", address: "x1b4n0q5v")
        // Too short checksum
        checkError(prefix: "li", address: "li1dgmt3")
        // checksum calculated with uppercase form of HRP
        checkError(prefix: "A", address: "A1G7SGD8")
        // empty HRP
        checkError(prefix: "", address: "10a06t8")

        HexEncodesToBech32(hex: "751e76e8199196d454941c45d1b3a323f1433bd6", prefix: "bc", cashBech32: "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4", version: 0, scriptType: .p2wpkh)
        HexEncodesToBech32(hex: "1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262", prefix: "tb", cashBech32: "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7", version: 0, scriptType: .p2wpkh)
    }

    func checkError(prefix: String, address: String) {
        do {
            let _ = try segWitBech32Converter.convert(prefix: prefix, address: address)
        } catch let error as AddressConverter.ConversionError {
            XCTAssertEqual(error, AddressConverter.ConversionError.unknownAddressType)
        } catch {
            XCTFail("Wrong \(error) exception")
        }
    }

    func HexEncodesToBech32(hex: String, prefix: String, cashBech32: String, version: UInt8, scriptType: ScriptType) {
        //Encode
        let data = Data(hex: hex)!
        do {
            let address = try segWitBech32Converter.convert(prefix: prefix, keyHash: data, scriptType: scriptType)
            XCTAssertEqual(address.scriptType, scriptType)
            XCTAssertEqual(address.keyHash, data)
            XCTAssertEqual(address.stringValue, cashBech32.lowercased())
        } catch {
            XCTFail("Exception \(error)")
        }
    }

}
