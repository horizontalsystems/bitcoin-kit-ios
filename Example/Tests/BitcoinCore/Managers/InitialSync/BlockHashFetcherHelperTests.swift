import XCTest
import Cuckoo
@testable import BitcoinCore

class BlockHashFetcherHelperTests: XCTestCase {

    private var helper = BlockHashFetcherHelper()
    private let addresses = [["address0_0", "address0_1"],
                             ["address1_0", "address1_1"]]

    func testLastUsedIndex_NotFound() {
        let outputs = [SyncTransactionOutputItem(script: "asdasd", address: "asdasd"),
                       SyncTransactionOutputItem(script: "tyrty", address: "sdfasdf")
        ]

        let result = helper.lastUsedIndex(addresses: addresses, outputs: outputs)
        XCTAssertEqual(-1, result)
    }

    func testLastUsedIndex_FoundFirstInAddress() {
        let outputs = [SyncTransactionOutputItem(script: "asdasd", address: "address0_0"),
                       SyncTransactionOutputItem(script: "tyrty", address: "sdfasdf")
        ]

        let result = helper.lastUsedIndex(addresses: addresses, outputs: outputs)
        XCTAssertEqual(0, result)
    }

    func testLastUsedIndex_FoundSecondInScript() {
        let outputs = [SyncTransactionOutputItem(script: "asdasd", address: "address0_0"),
                       SyncTransactionOutputItem(script: "ssfdaddress1_1aaqqw", address: "sdfasdf")
        ]

        let result = helper.lastUsedIndex(addresses: addresses, outputs: outputs)
        XCTAssertEqual(1, result)
    }

}
