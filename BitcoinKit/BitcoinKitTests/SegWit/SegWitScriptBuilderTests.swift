import XCTest
import Cuckoo
@testable import BitcoinKit
@testable import BitcoinCore

class SegWitScriptBuilderTests: XCTestCase {

    private var builder: SegWitScriptBuilder!

    override func setUp() {
        super.setUp()

        builder = SegWitScriptBuilder()
    }

    override func tearDown() {
        builder = nil

        super.tearDown()
    }

    func testP2WPKH() {
        let data = Data(hex: "751e76e8199196d454941c45d1b3a323f1433bd6")!
        let script = Data(hex: "0014751e76e8199196d454941c45d1b3a323f1433bd6")!
        let address = SegWitAddress(type: .pubKeyHash, keyHash: data, bech32: "", version: 0)
        do {
            let test = try builder.lockingScript(for: address)
            XCTAssertEqual(test, script)
        } catch {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testP2WSH() {
        let data = Data(hex: "1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262")!
        let script = Data(hex: "00201863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262")!
        let address = SegWitAddress(type: .pubKeyHash, keyHash: data, bech32: "", version: 0)
        do {
            let test = try builder.lockingScript(for: address)
            XCTAssertEqual(test, script)
        } catch {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNonSegwitAddress() {
        let address = LegacyAddress(type: .pubKeyHash, keyHash: Data(), base58: "")
        do {
            _ = try builder.lockingScript(for: address)
            XCTFail("Must throw exception")
        } catch let error as BitcoinKitErrors.AddressConversion {
            XCTAssertEqual(error, BitcoinKitErrors.AddressConversion.noSegWitAddress)
        } catch {
            XCTFail("\(error) Wrong Exception Thrown")
        }
    }

}
