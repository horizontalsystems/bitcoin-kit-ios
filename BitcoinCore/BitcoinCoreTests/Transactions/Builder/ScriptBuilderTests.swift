import XCTest
import Cuckoo
@testable import BitcoinCore

class ScriptBuilderTests: XCTestCase {

    private var builder: ScriptBuilder!

    override func setUp() {
        super.setUp()

        builder = ScriptBuilder()
    }

    override func tearDown() {
        builder = nil

        super.tearDown()
    }

    func testP2PKH() {
        let data = Data(hex: "76a914cbc20a7664f2f69e5355aa427045bc15e7c6c77288ac")!
        let pubKey = Data(hex: "cbc20a7664f2f69e5355aa427045bc15e7c6c772")!
        let address = LegacyAddress(type: .pubKeyHash, keyHash: pubKey, base58: "")
        do {
            let test = try builder.lockingScript(for: address)
            XCTAssertEqual(test, data)
        } catch {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testP2SH() {
        let data = Data(hex: "a9142a02dfd19c9108ad48878a01bfe53deaaf30cca487")!
        let pubKey = Data(hex: "2a02dfd19c9108ad48878a01bfe53deaaf30cca4")!
        let address = LegacyAddress(type: .scriptHash, keyHash: pubKey, base58: "")
        do {
            let test = try builder.lockingScript(for: address)
            XCTAssertEqual(test, data)
        } catch {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
