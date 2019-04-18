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

    func testP2PKHSig() {
        let data = Data(hex: "483045022100b78dacbc598d414f29537e33b5e7b209ecde9074b5fb4e68f94e8f5cb88ee9ad02202ef04916e8c1caa8cdb739c9695a51eadeaef6fe8ff7e990cc9031b410a123cc012103ec6877e5c28e459ac4daa3222204e7eef4cb42825b6b43438aeea01dd525b24d")!
        let pubKeys = [Data(hex: "3045022100b78dacbc598d414f29537e33b5e7b209ecde9074b5fb4e68f94e8f5cb88ee9ad02202ef04916e8c1caa8cdb739c9695a51eadeaef6fe8ff7e990cc9031b410a123cc01")!,
                       Data(hex: "03ec6877e5c28e459ac4daa3222204e7eef4cb42825b6b43438aeea01dd525b24d")!]

        let test = builder.unlockingScript(params: pubKeys)
        XCTAssertEqual(test, data)
    }

}
