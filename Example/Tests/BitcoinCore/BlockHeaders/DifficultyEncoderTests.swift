import XCTest
import Cuckoo
import BigInt
@testable import BitcoinCore

class DifficultyEncoderTests: XCTestCase {

    private var difficultyEncoder: DifficultyEncoder!

    override func setUp() {
        super.setUp()

        difficultyEncoder = DifficultyEncoder()
    }

    override func tearDown() {
        difficultyEncoder = nil

        super.tearDown()
    }

    func testCompactFromMaxHash() {
        let hash = Data(hex: "123456789012345678901234567890FFFF12345678901234567890123456FFFF")!
        let representation: Int = 0x2100ffff

        XCTAssertEqual(difficultyEncoder.compactFrom(hash: hash), representation)
    }

    func testCompactFromHashWithoutShift() {
        let hash = Data(hex: "123456789012345678901234567890FFFF12345678901234567890123456FF7F")!
        let representation: Int = 0x207fff56

        XCTAssertEqual(difficultyEncoder.compactFrom(hash: hash), representation)
    }

    func testCompactFromHashStandartWithoutShift() {
        let hash = Data(hex: "123456789012345678901234567890FFFF123456789012345678000000000000")!
        let representation: Int = 0x1a785634

        XCTAssertEqual(difficultyEncoder.compactFrom(hash: hash), representation)
    }

    func testCompactFromHashStandartWithShift() {
        let hash = Data(hex: "123456789012345678901234567890FFFF123456789012345681000000000000")!
        let representation: Int = 0x1b008156

        XCTAssertEqual(difficultyEncoder.compactFrom(hash: hash), representation)
    }

    func testCompactFromHashBiggest() {
        let hash = Data(hex: "0100000000000000000000000000000000000000000000000000000000000000")!
        let representation: Int = 0x03000001

        XCTAssertEqual(difficultyEncoder.compactFrom(hash: hash), representation)
    }

    func testEncodeCompact() {
        let difficulty: BigInt = BigInt("1234560000", radix: 16)!
        let representation: Int = 0x05123456

        XCTAssertEqual(difficultyEncoder.encodeCompact(from: difficulty), representation)
    }

    func testEncodeCompact_firstZero() {
        let difficulty: BigInt = BigInt("c0de000000", radix: 16)!
        let representation: Int = 0x0600c0de

        XCTAssertEqual(difficultyEncoder.encodeCompact(from: difficulty), representation)
    }

    func testEncodeCompact_negativeSign() {
        let difficulty: BigInt = BigInt("-40de000000", radix: 16)!
        let representation: Int = 0x05c0de00

        XCTAssertEqual(difficultyEncoder.encodeCompact(from: difficulty), representation)
    }

    func testDecodeCompact() {
        let difficulty: BigInt = BigInt("1234560000", radix: 16)!
        let representation: Int = 0x05123456

        XCTAssertEqual(difficultyEncoder.decodeCompact(bits: representation), difficulty)
    }

    func testDecodeCompact_firstZero() {
        let difficulty: BigInt = BigInt("c0de000000", radix: 16)!
        let representation: Int = 0x0600c0de

        XCTAssertEqual(difficultyEncoder.decodeCompact(bits: representation), difficulty)
    }

    func testDecodeCompact_negativeSign() {
        let difficulty: BigInt = BigInt("-40de000000", radix: 16)!
        let representation: Int = 0x05c0de00

        XCTAssertEqual(difficultyEncoder.decodeCompact(bits: representation), difficulty)
    }

}
