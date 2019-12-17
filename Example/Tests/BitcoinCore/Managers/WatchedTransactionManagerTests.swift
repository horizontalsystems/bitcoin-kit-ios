import Quick
import Nimble
import XCTest
import Cuckoo
import HdWalletKit
@testable import BitcoinCore

class WatchedTransactionManagerTests: QuickSpec {
    override func spec() {
        let mockBloomFilterManager = MockIBloomFilterManager()
        let mockP2ShFilterDelegate = MockIWatchedTransactionDelegate()
        let mockOutpointFilterDelegate = MockIWatchedTransactionDelegate()
        var manager: WatchedTransactionManager!

        let scriptHash = Data(repeating: 0, count: 32)
        let transactionHash = Data(repeating: 1, count: 32)
        let outputIndex = 1

        beforeEach {
            stub(mockBloomFilterManager) { mock in
                when(mock.regenerateBloomFilter()).thenDoNothing()
            }
            stub(mockP2ShFilterDelegate) { mock in
                when(mock.transactionReceived(transaction: any(), outputIndex: any())).thenDoNothing()
            }
            stub(mockOutpointFilterDelegate) { mock in
                when(mock.transactionReceived(transaction: any(), inputIndex: any())).thenDoNothing()
            }

            manager = WatchedTransactionManager(queue: DispatchQueue.main)
            manager.bloomFilterManager = mockBloomFilterManager
            manager.add(transactionFilter: .p2shOutput(scriptHash: scriptHash), delegatedTo: mockP2ShFilterDelegate)
            manager.add(transactionFilter: .outpoint(transactionHash: transactionHash, outputIndex: outputIndex), delegatedTo: mockOutpointFilterDelegate)
        }

        afterEach {
            reset(mockBloomFilterManager, mockP2ShFilterDelegate, mockOutpointFilterDelegate)

            manager = nil
        }

        describe("#add(transactionFilter:delegatedTo:)") {
            it("calls regenerateBloomFilter") {
                manager.add(transactionFilter: .p2shOutput(scriptHash: scriptHash), delegatedTo: mockP2ShFilterDelegate)
                verify(mockBloomFilterManager, times(3)).regenerateBloomFilter()
            }
        }

        describe("#onReceive") {
            it("matches against p2shOutput filters") {
                let transaction = TestData.p2shTransaction
                transaction.outputs[0].keyHash = scriptHash

                manager.onReceive(transaction: transaction)
                self.waitForMainQueue()

                verify(mockP2ShFilterDelegate).transactionReceived(transaction: equal(to: transaction), outputIndex: transaction.outputs[0].index)
                verify(mockOutpointFilterDelegate, never()).transactionReceived(transaction: any(), inputIndex: any())
            }

            it("matches against outpoint filters") {
                let transaction = TestData.p2shTransaction
                transaction.inputs[0].previousOutputTxHash = transactionHash
                transaction.inputs[0].previousOutputIndex = outputIndex

                manager.onReceive(transaction: transaction)
                self.waitForMainQueue()

                verify(mockP2ShFilterDelegate, never()).transactionReceived(transaction: any(), outputIndex: any())
                verify(mockOutpointFilterDelegate).transactionReceived(transaction: equal(to: transaction), inputIndex: 0)
            }
        }

        describe("#getFilterElements") {
            it("returns p2shOutput filters") {
                let elements = manager.filterElements()
                expect(elements).to(contain(scriptHash))
            }

            it("returns outpoint filters") {
                let elements = manager.filterElements()
                expect(elements).to(contain(transactionHash + byteArrayLittleEndian(int: outputIndex)))
            }
        }
    }

}
