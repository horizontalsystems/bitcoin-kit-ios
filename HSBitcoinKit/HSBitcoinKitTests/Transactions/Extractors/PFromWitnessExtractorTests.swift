import XCTest
import Cuckoo
@testable import HSBitcoinKit

class PFromWitnessExtractorTests: XCTestCase {

    private var scriptConverter: MockScriptConverter!
    private var extractor: ScriptExtractor!

    private var data: Data!
    private var redeemScriptData: Data!

    private var mockDataLastChunk: MockChunk!
    private var mockScript: MockScript!
    private var mockRedeemScript: MockScript!

    override func setUp() {
        super.setUp()

        data = Data(hex: "020000")!
        redeemScriptData = Data()

        mockDataLastChunk = MockChunk(scriptData: data, index: 0)

        mockScript = MockScript(with: Data(), chunks: [])
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(1)
            when(mock.chunks.get).thenReturn([mockDataLastChunk])
        }
        mockRedeemScript = MockScript(with: Data(), chunks: [])

        scriptConverter = MockScriptConverter()
        stub(scriptConverter) { mock in
            when(mock.decode(data: any())).thenReturn(mockRedeemScript)
        }

        extractor = PFromWitnessExtractor()
    }

    override func tearDown() {
        data = nil
        redeemScriptData = nil
        mockDataLastChunk = nil
        mockRedeemScript = nil
        mockScript = nil

        scriptConverter = nil
        extractor = nil

        super.tearDown()
    }

    func testValidExtract() {
        stub(mockDataLastChunk) { mock in
            when(mock.data.get).thenReturn(redeemScriptData)
        }
        stub(mockRedeemScript) { mock in
            when(mock.length.get).thenReturn(0)
            when(mock.validate(opCodes: any())).thenDoNothing()
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
            when(mock.length.get).thenReturn(20)
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

    func testWrongSequence() {
        stub(mockDataLastChunk) { mock in
            when(mock.data.get).thenReturn(nil)
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

    func testWrongSequenceTwoChunks() {
        stub(mockDataLastChunk) { mock in
            when(mock.data.get).thenReturn(redeemScriptData)
        }
        stub(mockScript) { mock in
            when(mock.chunks.get).thenReturn([mockDataLastChunk, mockDataLastChunk])
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
