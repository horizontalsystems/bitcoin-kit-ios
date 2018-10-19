import XCTest
import Cuckoo
@testable import HSBitcoinKit

class PFromWitnessExtractorTests: XCTestCase {

    private var scriptConverter: MockIScriptConverter!
    private var extractor: IScriptExtractor!

    private var redeemScriptData: Data!

    private var dataLastChunk: Chunk!
    private var mockScript: MockScript!
    private var mockRedeemScript: MockScript!

    override func setUp() {
        super.setUp()

        redeemScriptData = Data(hex: "020000")!
        dataLastChunk = Chunk(scriptData: redeemScriptData, index: 0, payloadRange: 0..<redeemScriptData.count)

        mockScript = MockScript(with: Data(), chunks: [])
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(1)
            when(mock.chunks.get).thenReturn([dataLastChunk])
        }
        mockRedeemScript = MockScript(with: Data(), chunks: [])

        scriptConverter = MockIScriptConverter()
        stub(scriptConverter) { mock in
            when(mock.decode(data: any())).thenReturn(mockRedeemScript)
        }

        extractor = PFromWitnessExtractor()
    }

    override func tearDown() {
        redeemScriptData = nil
        dataLastChunk = nil
        mockRedeemScript = nil
        mockScript = nil

        scriptConverter = nil
        extractor = nil

        super.tearDown()
    }

    func testValidExtract() {
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
        dataLastChunk = Chunk(scriptData: Data([0x00]), index: 0)
        stub(mockScript) { mock in
            when(mock.chunks.get).thenReturn([dataLastChunk])
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
        stub(mockScript) { mock in
            when(mock.chunks.get).thenReturn([dataLastChunk, dataLastChunk])
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
