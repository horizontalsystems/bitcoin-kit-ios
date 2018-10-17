import XCTest
import Cuckoo
@testable import HSBitcoinKit

class P2MultiSigExtractorTests: XCTestCase {

    private var extractor: ScriptExtractor!
    private var scriptConverter: MockScriptConverter!
    private var script: MockScript!
    private var data: Data!

    private var chunks: [Chunk]!
    private var mChunk: MockChunk!
    private var nChunk: MockChunk!
    private var checkChunk: MockChunk!

    override func setUp() {
        super.setUp()

        let mockBitcoinKit = MockBitcoinKit()

        data = Data(hex: "522102d83bba35a8022c247b645eed6f81ac41b7c1580de550e7e82c75ad63ee9ac2fe2103aeb681df5ac19e449a872b9e9347f1db5a0394d2ec5caf2a9c143f86e232b0d82103d728ad6757d4784effea04d47baafa216cf474866c2d4dc99b1e8e3eb936e73153ae")!

        scriptConverter = mockBitcoinKit.mockScriptConverter
        script = MockScript(with: Data(), chunks: [])

        mChunk = MockChunk(scriptData: data, index: 0)
        stub(mChunk) { mock in
            when(mock.opCode.get).thenReturn(0x52)
        }
        nChunk = MockChunk(scriptData: data, index: 103)
        stub(nChunk) { mock in
            when(mock.opCode.get).thenReturn(0x53)
        }
        checkChunk = MockChunk(scriptData: data, index: 104)
        stub(checkChunk) { mock in
            when(mock.opCode.get).thenReturn(UInt8(0xAE))
        }
        chunks = [mChunk, Chunk(scriptData: data, index: 1, payloadRange: 2..<35), Chunk(scriptData: data, index: 35, payloadRange: 36..<69), Chunk(scriptData: data, index: 69, payloadRange: 36..<103), nChunk, checkChunk]
        stub(script) { mock in
            when(mock.chunks.get).thenReturn(chunks)
        }

        extractor = P2MultiSigExtractor()
    }

    override func tearDown() {
        data = nil
        scriptConverter = nil
        script = nil
        extractor = nil

        super.tearDown()
    }

    func testValidExtract() {
        do {
            let test = try extractor.extract(from: script, converter: scriptConverter)
            XCTAssertEqual(test, nil)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testMinimalChunkCount() {
        let chunks = [Chunk(scriptData: data, index: 0), Chunk(scriptData: data, index: 103), Chunk(scriptData: data, index: 104)]
        stub(script) { mock in
            when(mock.chunks.get).thenReturn(chunks)
        }
        checkWrongSequenceError()
    }

    func testWrongM() {
        stub(mChunk) { mock in
            when(mock.opCode.get).thenReturn(0)
        }
        checkWrongSequenceError()
    }

    func testWrongN() {
        stub(nChunk) { mock in
            when(mock.opCode.get).thenReturn(0x88)
        }
        checkWrongSequenceError()
    }

    func testWrongMLessN() {
        stub(mChunk) { mock in
            when(mock.opCode.get).thenReturn(0x58)
        }
        stub(nChunk) { mock in
            when(mock.opCode.get).thenReturn(0x54)
        }
        checkWrongSequenceError()
    }

    func testCheckChunk() {
        stub(checkChunk) { mock in
            when(mock.opCode.get).thenReturn(0)
        }
        stub(script) { mock in
            when(mock.chunks.get).thenReturn(chunks)
        }
        checkWrongSequenceError()
    }

    func checkWrongSequenceError() {
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
