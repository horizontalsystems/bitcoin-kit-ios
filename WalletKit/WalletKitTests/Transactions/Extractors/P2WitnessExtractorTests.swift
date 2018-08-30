import XCTest
import Cuckoo
@testable import WalletKit

class P2WitnessExtractorTests: XCTestCase {

    private var scriptConverter: MockScriptConverter!
    private var extractor: ScriptExtractor!

    private var data: Data!
    private var redeemScriptData: Data!

    private var mockDataLastChunk: MockChunk!
    private var mockScript: MockScript!
    private var mockRedeemScript: MockScript!

    override func setUp() {
        super.setUp()

        data = Data(hex: "160014e7a4911954ca6a6972d2e6eceae53cd4163dc0ebfe")!
        redeemScriptData = Data(hex: "0014e7a4911954ca6a6972d2e6eceae53cd4163dc0ebfe")!

        mockDataLastChunk = MockChunk(scriptData: data, index: 0)

        mockScript = MockScript(with: Data(), chunks: [])
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
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(23)
            when(mock.chunks.get).thenReturn([mockDataLastChunk])
        }
        stub(mockRedeemScript) { mock in
            when(mock.validate(opCodes: any())).thenDoNothing()
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
        stub(mockScript) { mock in
            when(mock.length.get).thenReturn(23)
            when(mock.chunks.get).thenReturn([mockDataLastChunk])
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
            when(mock.length.get).thenReturn(23)
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
