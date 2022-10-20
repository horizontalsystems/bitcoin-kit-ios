import XCTest
import Cuckoo
@testable import BitcoinCore

class SegWitBech32AddressConverterTests: XCTestCase {
    private var segWitBech32Converter: SegWitBech32AddressConverter!
    private var mockScriptConverter: MockIScriptConverter!
    private let prefix = "tb1"

    override func setUp() {
        super.setUp()
        mockScriptConverter = MockIScriptConverter()
        segWitBech32Converter = SegWitBech32AddressConverter(prefix: "bc", scriptConverter: mockScriptConverter)
    }

    override func tearDown() {
        segWitBech32Converter = nil
        mockScriptConverter = nil

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

        var dataString = "0014751e76e8199196d454941c45d1b3a323f1433bd6"
        var data = Data(hex: dataString)!

        stub(mockScriptConverter) { mock in
            when(mock.decode(data: any())).thenReturn(Script(with: data, chunks: [Chunk(scriptData: data, index: 0), Chunk(scriptData: data, index: 1, payloadRange: 2..<22)]))
        }

        HexEncodesToBech32(hex: dataString, keyHash: Data(hex: "751e76e8199196d454941c45d1b3a323f1433bd6")!, prefix: "bc", cashBech32: "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4", version: 0, scriptType: .p2wpkh)

        dataString = "00201863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262"
        data = Data(hex: dataString)!
        stub(mockScriptConverter) { mock in
            when(mock.decode(data: any())).thenReturn(Script(with: data, chunks: [Chunk(scriptData: data, index: 0), Chunk(scriptData: data, index: 1, payloadRange: 2..<34)]))
        }
        HexEncodesToBech32(hex: dataString, keyHash: Data(hex: "1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262")!, prefix: "bc", cashBech32: "bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3", version: 0, scriptType: .p2wpkh)

        dataString = "5128751e76e8199196d454941c45d1b3a323f1433bd6751e76e8199196d454941c45d1b3a323f1433bd6"
        data = Data(hex: dataString)!
        stub(mockScriptConverter) { mock in
            when(mock.decode(data: any())).thenReturn(Script(with: data, chunks: [Chunk(scriptData: data, index: 0), Chunk(scriptData: data, index: 1, payloadRange: 2..<42)]))
        }
        HexEncodesToBech32(hex: dataString, keyHash: Data(hex: "751e76e8199196d454941c45d1b3a323f1433bd6751e76e8199196d454941c45d1b3a323f1433bd6")!, prefix: "bc", cashBech32: "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7k7grplx", version: 1, scriptType: .p2wpkh)
    }

    func checkError(prefix: String, address: String) {
        do {
            let _ = try segWitBech32Converter.convert(address: address)
        } catch let error as BitcoinCoreErrors.AddressConversion {
            XCTAssertEqual(error, BitcoinCoreErrors.AddressConversion.unknownAddressType)
        } catch {
            XCTFail("Wrong \(error) exception")
        }
    }

    func HexEncodesToBech32(hex: String, keyHash: Data, prefix: String, cashBech32: String, version: UInt8, scriptType: ScriptType) {
        //Encode
        let data = Data(hex: hex)!
        do {
            let address = try segWitBech32Converter.convert(keyHash: data, type: scriptType)
            XCTAssertEqual(address.scriptType, scriptType)
            XCTAssertEqual(address.keyHash, keyHash)
            XCTAssertEqual(address.stringValue, cashBech32.lowercased())
        } catch {
            XCTFail("Exception \(error)")
        }
    }

}
