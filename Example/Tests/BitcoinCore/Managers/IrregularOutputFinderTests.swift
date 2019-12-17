import Quick
import Nimble
import XCTest
import Cuckoo
import HdWalletKit
@testable import BitcoinCore

class IrregularOutputFinderTests: QuickSpec {
    override func spec() {
        let mockStorage = MockIStorage()
        let lastBlock = TestData.checkpointBlock

        var finder: IrregularOutputFinder!
        var elements: [Data]!

        beforeEach {
            stub(mockStorage) { mock in
                when(mock.lastBlock.get).thenReturn(lastBlock)
            }

            finder = IrregularOutputFinder(storage: mockStorage)
        }

        afterEach {
            reset(mockStorage)
            finder = nil
        }

        describe("#filterElements") {
            let output1 = TestData.p2wpkhTransaction.outputs[0]
            output1.transactionHash = Data(repeating: 0, count: 32)

            beforeEach {
                stub(mockStorage) { mock in
                    when(mock.publicKeys()).thenReturn([])
                }
            }

            context("when output is not spent") {
                beforeEach {
                    stub(mockStorage) { mock in
                        when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: nil, spendingBlockHeight: nil)])
                    }
                }

                it("returns outputs") {
                    elements = finder.filterElements()

                    let expectedElements = [output1.transactionHash + self.byteArrayLittleEndian(int: output1.index)]
                    expect(elements).to(equal(expectedElements))
                }
            }

            context("when output is spent") {
                let input = TestData.p2pkhTransaction.inputs[0]
                input.previousOutputTxHash = output1.transactionHash
                input.previousOutputIndex = output1.index

                context("when spending transaction is in mempool") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: input, spendingBlockHeight: nil)])
                        }
                    }

                    it("returns output") {
                        elements = finder.filterElements()

                        let expectedElements = [output1.transactionHash + self.byteArrayLittleEndian(int: output1.index)]
                        expect(elements).to(equal(expectedElements))
                    }
                }

                context("when spending transaction is in block") {
                    context("when block is not far enough in history") {
                        beforeEach {
                            stub(mockStorage) { mock in
                                when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: input, spendingBlockHeight: lastBlock.height - 98)])
                            }
                        }

                        it("returns output") {
                            elements = finder.filterElements()

                            let expectedElements = [output1.transactionHash + self.byteArrayLittleEndian(int: output1.index)]
                            expect(elements).to(equal(expectedElements))
                        }
                    }

                    context("when block is far enough") {
                        beforeEach {
                            stub(mockStorage) { mock in
                                when(mock.outputsWithPublicKeys()).thenReturn([OutputWithPublicKey(output: output1, publicKey: TestData.pubKey(), spendingInput: input, spendingBlockHeight: lastBlock.height - 100)])
                            }
                        }

                        it("doesn't return output") {
                            elements = finder.filterElements()
                            expect(elements).to(equal([Data]()))
                        }
                    }
                }
            }
        }
    }

    private func getPublicKey(withIndex index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        let hdPrivKeyData = try! hdWallet.privateKeyData(account: 0, index: index, external: chain == .external)
        return PublicKey(withAccount: 0, index: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }

    private func byteArrayLittleEndian(int: Int) -> [UInt8] {
        return [
            UInt8(int & 0x000000FF),
            UInt8((int & 0x0000FF00) >> 8),
            UInt8((int & 0x00FF0000) >> 16),
            UInt8((int & 0xFF000000) >> 24)
        ]
    }

}
