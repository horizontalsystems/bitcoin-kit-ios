import XCTest
import Cuckoo
@testable import WalletKit

class WitnessExtractorTests: XCTestCase {

    private var scriptConverter: MockScriptConverter!
    private var extractor: ScriptExtractor!

    private var data: Data!
    private var redeemScriptData: Data!

    private var mockScript: MockScript!

    override func setUp() {
        super.setUp()

        data = Data(hex: "020000")!
        redeemScriptData = Data()


        mockScript = MockScript(with: Data(), chunks: [])

        scriptConverter = MockScriptConverter()
        extractor = WitnessExtractor()
    }

    override func tearDown() {
        data = nil
        redeemScriptData = nil
        mockScript = nil

        scriptConverter = nil
        extractor = nil

        super.tearDown()
    }

    func testValidExtract() {
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(0)
            when(mock.chunks.get).thenReturn([Chunk(scriptData: Data([0x00]), index: 0), Chunk(scriptData: Data([0x00]), index: 0, payloadRange: 0..<0)])
        }

        do {
            let test = try extractor.extract(from: mockScript, converter: scriptConverter)
            XCTAssertEqual(test, redeemScriptData)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testWrongScriptLength() {
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(5)
            when(mock.chunks.get).thenReturn([Chunk(scriptData: Data([0x00]), index: 0), Chunk(scriptData: Data([0x00]), index: 0), Chunk(scriptData: Data([0x00]), index: 0, payloadRange: 0..<0)])
        }

        do {
            let _ = try extractor.extract(from: mockScript, converter: scriptConverter)
            XCTFail("No Error found!")
        } catch let error as ScriptError {
            XCTAssertEqual(error, ScriptError.wrongScriptLength)
        } catch {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testWrongScriptChunksCount() {
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(0)
            when(mock.chunks.get).thenReturn([Chunk(scriptData: Data([0x00]), index: 0), Chunk(scriptData: Data([0x00]), index: 0), Chunk(scriptData: Data([0x00]), index: 0, payloadRange: 0..<0)])
        }

        do {
            let _ = try extractor.extract(from: mockScript, converter: scriptConverter)
            XCTFail("No Error found!")
        } catch let error as ScriptError {
            XCTAssertEqual(error, ScriptError.wrongSequence)
        } catch {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testWrongScriptPushCode() {
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(0)
            when(mock.chunks.get).thenReturn([Chunk(scriptData: Data([0x16]), index: 0), Chunk(scriptData: Data([0x00]), index: 0, payloadRange: 0..<0)])
        }

        do {
            let _ = try extractor.extract(from: mockScript, converter: scriptConverter)
            XCTFail("No Error found!")
        } catch let error as ScriptError {
            XCTAssertEqual(error, ScriptError.wrongSequence)
        } catch {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
