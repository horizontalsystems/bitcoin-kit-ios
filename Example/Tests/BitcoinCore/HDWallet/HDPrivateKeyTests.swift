import XCTest
import Cuckoo
import HdWalletKit
@testable import BitcoinCore

class HDPrivateKeyTests: XCTestCase {
    private var mockNetwork: MockINetwork!

    override func setUp() {
        super.setUp()

        mockNetwork = MockINetwork()

        stub(mockNetwork) { mock in
            when(mock.xPrivKey.get).thenReturn(0x04358394)
            when(mock.xPubKey.get).thenReturn(0x043587cf)
        }
    }

    override func tearDown() {
        mockNetwork = nil
        super.tearDown()
    }

    func testCorrectDerivedKey() {
        let privateKey = HDPrivateKey(privateKey: Data(hex: "6a787b30bd81c8fa5ed09175b5fb08e179cf429ba91ca649dd3317436b7b698e")!, chainCode: Data(), xPrivKey: mockNetwork.xPrivKey, xPubKey: mockNetwork.xPubKey)

        XCTAssertEqual(privateKey.raw.hex, "6a787b30bd81c8fa5ed09175b5fb08e179cf429ba91ca649dd3317436b7b698e")
    }

    func testCorrectDerivedKey_SmallLength() {
        let privateKey = HDPrivateKey(privateKey: Data(hex: "4c16165875d0bed9a76e4ba83fae65c80076f60791d956f336a2d7a3b21185")!, chainCode: Data(), xPrivKey: mockNetwork.xPrivKey, xPubKey: mockNetwork.xPubKey)

        XCTAssertEqual(privateKey.raw.hex, "004c16165875d0bed9a76e4ba83fae65c80076f60791d956f336a2d7a3b21185")
    }

}
