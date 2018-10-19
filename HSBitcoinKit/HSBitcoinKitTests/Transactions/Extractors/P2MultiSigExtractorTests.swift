import XCTest
import Cuckoo
@testable import HSBitcoinKit

class P2MultiSigExtractorTests: XCTestCase {

    private var extractor: IScriptExtractor!
    private var scriptConverter: MockIScriptConverter!
    private var script: MockScript!

    private var chunks: [Chunk]!
    private var mChunk: Chunk!
    private var nChunk: Chunk!
    private var checkChunk: Chunk!

    override func setUp() {
        super.setUp()

        scriptConverter = MockIScriptConverter()
        script = MockScript(with: Data(), chunks: [])

        mChunk = Chunk(scriptData: Data([0x52]), index: 0)
        nChunk = Chunk(scriptData: Data([0x53]), index: 0)
        checkChunk = Chunk(scriptData: Data([0xAE]), index: 0)

        let stubChunk = Chunk(scriptData: Data([0]), index: 0)
        chunks = [mChunk, stubChunk, nChunk, checkChunk]
        extractor = P2MultiSigExtractor()
    }

    override func tearDown() {
        scriptConverter = nil
        script = nil
        extractor = nil

        super.tearDown()
    }

    func testValidExtract() {
        stub(script) { mock in
            when(mock.chunks.get).thenReturn(chunks)
        }
        do {
            let test = try extractor.extract(from: script, converter: scriptConverter)
            XCTAssertEqual(test, nil)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testMinimalChunkCount() {
        let stubChunk = Chunk(scriptData: Data([0]), index: 0)
        chunks = [stubChunk, stubChunk, stubChunk]
        checkWrongSequenceError()
    }

    func testWrongM() {
        chunks[0] = Chunk(scriptData: Data([3]), index: 0)
        checkWrongSequenceError()
    }

    func testWrongN() {
        chunks[2] = Chunk(scriptData: Data([3]), index: 0)
        checkWrongSequenceError()
    }

    func testWrongMLessN() {
        chunks[0] = Chunk(scriptData: Data([0x58]), index: 0)
        chunks[2] = Chunk(scriptData: Data([0x54]), index: 0)
        checkWrongSequenceError()
    }

    func testCheckChunk() {
        chunks[3] = Chunk(scriptData: Data([3]), index: 0)
        checkWrongSequenceError()
    }

    func checkWrongSequenceError() {
        stub(script) { mock in
            when(mock.chunks.get).thenReturn(chunks)
        }
        do {
            _ = try extractor.extract(from: script, converter: scriptConverter)
            XCTFail("No Exception Thrown")
        } catch let error as ScriptError {
            XCTAssertEqual(error, ScriptError.wrongSequence)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
