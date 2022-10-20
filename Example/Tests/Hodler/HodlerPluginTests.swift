import XCTest
import Cuckoo
import Nimble
import Quick
import OpenSslKit
@testable import BitcoinCore
@testable import Hodler

class HodlerPluginTests: QuickSpec {
    override func spec() {
        let mockAddressConverter = MockIHodlerAddressConverter()
        let mockStorage = MockIHodlerPublicKeyStorage()
        let mockBlockMedianTimeHelper = MockIHodlerBlockMedianTimeHelper()

        let p2pkhAddress = LegacyAddress(type: .pubKeyHash, keyHash: Data(repeating: 0, count: 20), base58: "")
        let p2shAddress = LegacyAddress(type: .scriptHash, keyHash: self.scriptHash(from: p2pkhAddress.keyHash), base58: "")
        let publicKey = PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data())
        let currentTimestamp = Int(Date().timeIntervalSince1970)

        var hodler: HodlerPlugin!
        var transaction: FullTransaction!

        beforeEach {
            transaction = FullTransaction(
                    header: Transaction(lockTime: 0, timestamp: currentTimestamp),
                    inputs: [], outputs: [Output(withValue: 0, index: 0, lockingScript: Data(), keyHash: p2shAddress.keyHash)]
            )

            hodler = HodlerPlugin(addressConverter: mockAddressConverter, blockMedianTimeHelper: mockBlockMedianTimeHelper, publicKeyStorage: mockStorage)
        }

        afterEach {
            reset(mockAddressConverter, mockStorage, mockBlockMedianTimeHelper)
        }

        describe("#processOutputs") {
            var mutableTransaction: MutableTransaction!

            beforeEach {
                mutableTransaction = MutableTransaction()
                mutableTransaction.recipientAddress = p2pkhAddress

                stub(mockAddressConverter) { mock in
                    when(mock.convert(keyHash: any(), type: equal(to: ScriptType.p2sh))).thenReturn(p2shAddress)
                }
            }

            context("when pluginData is valid") {
                beforeEach {
                    try! hodler.processOutputs(mutableTransaction: mutableTransaction, pluginData: HodlerData(lockTimeInterval: HodlerPlugin.LockTimeInterval.hour))
                }

                it("generates correct scriptHash") {
                    verify(mockAddressConverter).convert(keyHash: equal(to: p2shAddress.keyHash), type: equal(to: ScriptType.p2sh))
                }

                it("sets new P2SH address") {
                    expect(mutableTransaction.recipientAddress.stringValue).to(equal(p2shAddress.stringValue))
                }

                fit("sets pluginData") {
                    guard let pluginData = mutableTransaction.pluginData[HodlerPlugin.id] else {
                        fail("Must have pluginData output")
                        return
                    }

                    let expectedLockingScript = Data(hex: "020700140000000000000000000000000000000000000000")!
                    expect(pluginData).to(equal(expectedLockingScript))
                }
            }

            context("invalid hodler data") {
                it("throws invalidData") {
                    do {
                        try hodler.processOutputs(mutableTransaction: mutableTransaction, pluginData: OtherPluginData())
                        fail("Exception expected")
                    } catch let error as HodlerPluginError {
                        expect(error).to(equal(HodlerPluginError.invalidData))
                    } catch {
                        fail("Unexpected exception")
                    }
                }
            }

            context("recipientAddress not p2pkh") {
                context("skipChecks is false") {
                    it("throws unsupportedAddress") {
                        mutableTransaction.recipientAddress = p2shAddress
                        do {
                            try hodler.processOutputs(mutableTransaction: mutableTransaction, pluginData: HodlerData(lockTimeInterval: HodlerPlugin.LockTimeInterval.hour))
                            fail("Exception expected")
                        } catch let error as HodlerPluginError {
                            expect(error).to(equal(HodlerPluginError.unsupportedAddress))
                        } catch {
                            fail("Unexpected exception")
                        }
                    }
                }

                context("skipChecks is true") {
                    it("doesn't throw unsupportedAddress") {
                        mutableTransaction.recipientAddress = p2shAddress
                        do {
                            try hodler.processOutputs(mutableTransaction: mutableTransaction, pluginData: HodlerData(lockTimeInterval: HodlerPlugin.LockTimeInterval.hour), skipChecks: true)
                        } catch {
                            fail("Unexpected exception")
                        }
                    }
                }
            }
        }

        describe("#processTransactionWithNullData") {
            let chunks = [
                Chunk(scriptData: Data([0x02, 0x07, 0x00]), index: 0, payloadRange: 1..<3),
                Chunk(scriptData: p2pkhAddress.keyHash, index: 1, payloadRange: 0..<20)
            ]

            context("when valid nullData output") {
                beforeEach {
                    stub(mockAddressConverter) { mock in
                        when(mock.convert(keyHash: equal(to: p2pkhAddress.keyHash), type: equal(to: ScriptType.p2pkh))).thenReturn(p2pkhAddress)
                    }
                }

                context("when publicKey is found") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.publicKey(byRawOrKeyHash: equal(to: p2pkhAddress.keyHash))).thenReturn(publicKey)
                        }

                        var chunksIterator = chunks.makeIterator()
                        try! hodler.processTransactionWithNullData(transaction: transaction, nullDataChunks: &chunksIterator)
                    }

                    it("sets pluginId and pluginData to output") {
                        expect(transaction.outputs[0].pluginId).to(equal(HodlerPlugin.id))
                        expect(transaction.outputs[0].pluginData).to(equal("7|\(p2pkhAddress.stringValue)"))
                    }

                    it("sets publicKey and redeemScript and transaction.isMine flag") {
                        expect(transaction.outputs[0].redeemScript).to(equal(self.redeemScript(from: p2pkhAddress.keyHash)))
                        expect(transaction.outputs[0].publicKeyPath).to(equal(publicKey.path))
                        expect(transaction.header.isMine).to(beTrue())
                    }
                }

                context("when publicKey is not found") {
                    beforeEach {
                        stub(mockStorage) { mock in
                            when(mock.publicKey(byRawOrKeyHash: equal(to: p2pkhAddress.keyHash))).thenReturn(nil)
                        }

                        var chunksIterator = chunks.makeIterator()
                        try! hodler.processTransactionWithNullData(transaction: transaction, nullDataChunks: &chunksIterator)
                    }

                    it("sets pluginId and pluginData to output") {
                        expect(transaction.outputs[0].pluginId).to(equal(HodlerPlugin.id))
                        expect(transaction.outputs[0].pluginData).to(equal("7|\(p2pkhAddress.stringValue)"))
                    }

                    it("doesn't set publicKey and redeemScript and transaction.isMine flag") {
                        expect(transaction.outputs[0].redeemScript).to(beNil())
                        expect(transaction.outputs[0].publicKeyPath).to(beNil())
                        expect(transaction.header.isMine).to(beFalse())
                    }
                }
            }

            context("when invalid nullData output") {
                it("throws invalidData") {
                    var chunksIterator = [Chunk]().makeIterator()

                    do {
                        try hodler.processTransactionWithNullData(transaction: transaction, nullDataChunks: &chunksIterator)
                        fail("Exception expected")
                    } catch let error as HodlerPluginError {
                        expect(error).to(equal(HodlerPluginError.invalidData))
                    } catch {
                        fail("Unexpected error")
                    }
                }
            }
        }

        describe("#isSpendable") {
            let output = Output(withValue: 0, index: 0, lockingScript: Data())
            output.pluginData = "\(HodlerPlugin.LockTimeInterval.hour.rawValue)|someAddressString"
            var unspentOutput: UnspentOutput!

            beforeEach {
                unspentOutput = UnspentOutput(output: output, publicKey: publicKey, transaction: transaction.header)
            }

            context("when lastBlockMedianTime is can't be retrieved") {
                it("return false") {
                    stub(mockBlockMedianTimeHelper) { mock in
                        when(mock.medianTimePast.get).thenReturn(nil)
                    }

                    expect(try! hodler.isSpendable(unspentOutput: unspentOutput)).to(beFalse())
                }
            }

            context("when lastBlockMedianTime is more than unlock time") {
                it("return false") {
                    stub(mockBlockMedianTimeHelper) { mock in
                        when(mock.medianTimePast.get).thenReturn(currentTimestamp + HodlerPlugin.LockTimeInterval.hour.valueInSeconds - 1)
                    }

                    expect(try! hodler.isSpendable(unspentOutput: unspentOutput)).to(beFalse())
                }
            }

            context("when lastBlockMedianTime is less than unlock time") {
                it("return false") {
                    stub(mockBlockMedianTimeHelper) { mock in
                        when(mock.medianTimePast.get).thenReturn(currentTimestamp + HodlerPlugin.LockTimeInterval.hour.valueInSeconds + 1)
                    }

                    expect(try! hodler.isSpendable(unspentOutput: unspentOutput)).to(beTrue())
                }
            }
        }

        describe("#inputSequenceNumber") {
            let output = Output(withValue: 0, index: 0, lockingScript: Data())
            output.pluginData = "\(HodlerPlugin.LockTimeInterval.hour.rawValue)|someAddressString"

            it("returns UInt32 sequenceNumber") {
                expect(try! hodler.inputSequenceNumber(output: output)).to(equal(Int(Int(HodlerPlugin.LockTimeInterval.hour.rawValue) + 0x400000)))
            }
        }
    }

    private func scriptHash(from publicKeyHash: Data) -> Data {
        Kit.sha256ripemd160(redeemScript(from: publicKeyHash))
    }

    private func redeemScript(from publicKeyHash: Data) -> Data {
        OpCode.push(Data([0x07, 0x00, 0x40])) + Data([OpCode.checkSequenceVerify, OpCode.drop]) + OpCode.p2pkhStart + OpCode.push(publicKeyHash) + OpCode.p2pkhFinish
    }

}

class OtherPluginData: IPluginData {
}
