//import Quick
//import Nimble
//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class UnspentOutputProviderTests: QuickSpec {
//    override func spec() {
//        let mockStorage = MockIStorage()
//
//        let output = Output(withValue: 1, index: 0, lockingScript: Data(), type: .p2pkh, keyHash: Data(hex: "000010000")!)
//        let pubKey = TestData.pubKey()
//        let lastBlockHeight = 550368
//        let lastBlock = Block(withHeader: TestData.checkpointBlock.header, height: lastBlockHeight)
//        let confirmationsThreshold = 6
//
//        var unspentOutput: UnspentOutput!
//
//        let provider = UnspentOutputProvider(storage: mockStorage, confirmationsThreshold: confirmationsThreshold)
//
//        beforeEach {
//            stub(mockStorage) { mock in
//                when(mock.lastBlock.get).thenReturn(lastBlock)
//            }
//        }
//
//        afterEach {
//            reset(mockStorage)
//            unspentOutput = nil
//        }
//
//        describe("#allUnspentOutputs") {
//            context("when transaction is outgoing") {
//                beforeEach {
//                    let transaction = Transaction()
//                    transaction.isOutgoing = true
//                    unspentOutput = UnspentOutput(output: output, publicKey: pubKey, transaction: transaction, block: nil)
//
//                    stub(mockStorage) { mock in
//                        when(mock.unspentOutputs()).thenReturn([unspentOutput])
//                    }
//                }
//
//                it("returns unspentOutput") {
//                    expect(provider.allUnspentOutputs).to(equal([unspentOutput]))
//                }
//            }
//
//            context("when transaction is not outgoing") {
//                var transaction: Transaction!
//
//                beforeEach {
//                    transaction = Transaction()
//                    transaction.isOutgoing = false
//                }
//
//                context("when transaction is not included in block") {
//                    beforeEach {
//                        unspentOutput = UnspentOutput(output: output, publicKey: pubKey, transaction: transaction, block: nil)
//
//                        stub(mockStorage) { mock in
//                            when(mock.unspentOutputs()).thenReturn([unspentOutput])
//                        }
//                    }
//
//                    it("doesn't return unspentOutput") {
//                        expect(provider.allUnspentOutputs).to(equal([]))
//                    }
//                }
//
//                context("when transaction is included in block") {
//                    var block: Block!
//
//                    beforeEach {
//                        block = TestData.firstBlock
//                        unspentOutput = UnspentOutput(output: output, publicKey: pubKey, transaction: transaction, block: block)
//
//                        stub(mockStorage) { mock in
//                            when(mock.unspentOutputs()).thenReturn([unspentOutput])
//                        }
//                    }
//
//                    context("when block has enough confirmations") {
//                        it("returns unspentOutput") {
//                            block.height = lastBlock.height - confirmationsThreshold
//                            expect(provider.allUnspentOutputs).to(equal([unspentOutput]))
//                        }
//                    }
//
//                    context("when block has not enough confirmations") {
//                        it("doesn't return unspentOutput") {
//                            block.height = lastBlock.height - confirmationsThreshold + 2
//                            expect(provider.allUnspentOutputs).to(equal([]))
//                        }
//                    }
//                }
//            }
//        }
//
//        describe("#balance") {
//            it("returns sum of unspentOutputs") {
//                let transaction = Transaction()
//                transaction.isOutgoing = true
//                let unspentOutputs = [
//                    UnspentOutput(output: output, publicKey: pubKey, transaction: transaction, block: nil),
//                    UnspentOutput(output: output, publicKey: pubKey, transaction: transaction, block: nil)
//                ]
//
//                stub(mockStorage) { mock in
//                    when(mock.unspentOutputs()).thenReturn(unspentOutputs)
//                }
//
//                expect(provider.balance).to(equal(unspentOutputs[0].output.value + unspentOutputs[1].output.value))
//            }
//        }
//    }
//}
