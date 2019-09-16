import XCTest
import Cuckoo
import Nimble
import Quick
@testable import BitcoinCore

class TransactionCreatorTests: QuickSpec {
    override func spec() {
        let mockTransactionBuilder = MockITransactionBuilder()
        let mockTransactionProcessor = MockITransactionProcessor()
        let mockTransactionFeeCalculator = MockITransactionFeeCalculator()
        let mockTransactionSender = MockITransactionSender()
        let mockBloomFilterManager = MockIBloomFilterManager()
        let mockAddressConverter = MockIAddressConverter()
        let mockPublicKeyManager = MockIPublicKeyManager()
        let mockStorage = MockIStorage()

        let transaction = TestData.p2pkhTransaction
        let changePublicKey = TestData.pubKey()

        let toAddress = LegacyAddress(type: .pubKeyHash, keyHash: randomBytes(length: 32), base58: "toAddressPKH")
        let changeAddress = LegacyAddress(type: .pubKeyHash, keyHash: randomBytes(length: 32), base58: "changeAddressPKH")

        let sendingValue = 100_000_000
        let feeRate = 1000
        let senderPay = true
        let bip = Bip.bip44
        let lastBlock = TestData.firstBlock

        var unspentOutputs: [UnspentOutput]!
        var selectedOutputsInfo: SelectedUnspentOutputInfo!

        var creator: TransactionCreator!

        beforeEach {
            unspentOutputs = [
                UnspentOutput(
                    output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2pkh),
                    publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                    transaction: Transaction(),
                    blockHeight: 1000
                )
            ]
            selectedOutputsInfo = SelectedUnspentOutputInfo(unspentOutputs: unspentOutputs, totalValue: 100_000_000, fee: 1000, addChangeOutput: true)

            stub(mockStorage) { mock in
                when(mock.lastBlock.get).thenReturn(lastBlock)
            }
            stub(mockTransactionFeeCalculator) { mock in
                when(mock).feeWithUnspentOutputs(value: sendingValue, feeRate: any(), toScriptType: any(), changeScriptType: any(), senderPay: any()).thenReturn(selectedOutputsInfo)
            }
            stub(mockAddressConverter) { mock in
                when(mock.convert(address: equal(to: toAddress.stringValue))).thenReturn(toAddress)
                when(mock.convert(address: equal(to: changeAddress.stringValue))).thenReturn(changeAddress)
                when(mock.convert(keyHash: equal(to: toAddress.keyHash), type: equal(to: toAddress.scriptType))).thenReturn(toAddress)
                when(mock.convert(publicKey: equal(to: changePublicKey), type: equal(to: changeAddress.scriptType))).thenReturn(changeAddress)
            }
            stub(mockPublicKeyManager) { mock in
                when(mock).changePublicKey().thenReturn(changePublicKey)
            }
            stub(mockTransactionBuilder) { mock in
                when(mock.buildTransaction(value: any(), unspentOutputs: any(), fee: any(), senderPay: any(), toAddress: any(), changeAddress: any(), lastBlockHeight: any())).thenReturn(transaction)
            }
            stub(mockTransactionProcessor) { mock in
                when(mock.processCreated(transaction: any())).thenDoNothing()
            }
            stub(mockTransactionSender) { mock in
                when(mock.send(pendingTransaction: any())).thenDoNothing()
            }
            stub(mockBloomFilterManager) { mock in
                when(mock.regenerateBloomFilter()).thenDoNothing()
            }

            creator = TransactionCreator(
                    transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, transactionSender: mockTransactionSender, transactionFeeCalculator: mockTransactionFeeCalculator,
                    bloomFilterManager: mockBloomFilterManager, addressConverter: mockAddressConverter, publicKeyManager: mockPublicKeyManager, storage: mockStorage, bip: bip
            )
        }

        afterEach {
            reset(mockTransactionBuilder, mockTransactionProcessor, mockTransactionFeeCalculator, mockTransactionSender, mockBloomFilterManager, mockAddressConverter, mockPublicKeyManager)
            creator = nil
        }

        describe("#create(to:value:feeRate:senderPay:)") {
            context("when all valid, addChangeOutput is true") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }
                    _ = try! creator.create(to: toAddress.stringValue, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("parses address string") {
                    verify(mockAddressConverter).convert(address: equal(to: toAddress.stringValue))
                }

                it("calculates fee and selects unspent outputs") {
                    verify(mockTransactionFeeCalculator).feeWithUnspentOutputs(value: sendingValue, feeRate: feeRate, toScriptType: equal(to: toAddress.scriptType), changeScriptType: equal(to: bip.scriptType), senderPay: senderPay)
                }

                it("generates change address") {
                    verify(mockPublicKeyManager).changePublicKey()
                    verify(mockAddressConverter).convert(publicKey: equal(to: changePublicKey), type: equal(to: bip.scriptType))
                }

                it("creates transaction") {
                    verify(mockTransactionBuilder).buildTransaction(value: sendingValue, unspentOutputs: equal(to: unspentOutputs), fee: selectedOutputsInfo.fee, senderPay: senderPay, toAddress: addressMatcher(toAddress), changeAddress: addressMatcher(changeAddress), lastBlockHeight: lastBlock.height)
                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                }

                it("sends transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }
            }

            context("when addChangeOutput is false") {
                beforeEach {
                    selectedOutputsInfo = SelectedUnspentOutputInfo(unspentOutputs: unspentOutputs, totalValue: 100_000_000, fee: 1000, addChangeOutput: false)

                    stub(mockTransactionFeeCalculator) { mock in
                        when(mock).feeWithUnspentOutputs(value: sendingValue, feeRate: any(), toScriptType: any(), changeScriptType: any(), senderPay: any()).thenReturn(selectedOutputsInfo)
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }
                    _ = try! creator.create(to: toAddress.stringValue, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("creates transaction without change address") {
                    verify(mockPublicKeyManager, never()).changePublicKey()
                    verify(mockAddressConverter, never()).convert(publicKey: equal(to: changePublicKey), type: equal(to: bip.scriptType))
                    verify(mockTransactionBuilder).buildTransaction(value: sendingValue, unspentOutputs: any(), fee: selectedOutputsInfo.fee, senderPay: senderPay, toAddress: addressMatcher(toAddress), changeAddress: addressMatcher(nil), lastBlockHeight: lastBlock.height)
                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                }
            }

            context("when lastBlock is nil") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }
                    stub(mockStorage) { mock in
                        when(mock.lastBlock.get).thenReturn(nil)
                    }

                    _ = try! creator.create(to: toAddress.stringValue, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("builds transactions with lastBlockHeight: 0") {
                    verify(mockTransactionBuilder).buildTransaction(value: sendingValue, unspentOutputs: equal(to: unspentOutputs), fee: selectedOutputsInfo.fee, senderPay: senderPay, toAddress: addressMatcher(toAddress), changeAddress: addressMatcher(changeAddress), lastBlockHeight: 0)
                }
            }

            context("when BloomFilterManager.BloomFilterExpired error") {
                beforeEach {
                    stub(mockTransactionProcessor) { mock in
                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try? creator.create(to: toAddress.stringValue, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("does create transaction") {
                    verify(mockTransactionBuilder).buildTransaction(value: sendingValue, unspentOutputs: any(), fee: selectedOutputsInfo.fee, senderPay: senderPay, toAddress: addressMatcher(toAddress), changeAddress: addressMatcher(changeAddress), lastBlockHeight: lastBlock.height)
                    verify(mockTransactionProcessor).processCreated(transaction: any())
                }

                it("does send transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }

                it("regenerates bloomfilter") {
                    verify(mockBloomFilterManager).regenerateBloomFilter()
                }
            }

            context("when other error") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenThrow(BitcoinCoreErrors.TransactionSendError.noConnectedPeers)
                    }

                    _ = try? creator.create(to: toAddress.stringValue, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
                }

                it("doesn't create transaction") {
                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
                }

                it("doesn't regenerate bloomfilter") {
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }
        }

        describe("#create(to:scriptType:value:feeRate:senderPay:)") {
            beforeEach {
                stub(mockTransactionSender) { mock in
                    when(mock.verifyCanSend()).thenDoNothing()
                }
                _ = try! creator.create(to: toAddress.keyHash, scriptType: toAddress.scriptType, value: sendingValue, feeRate: feeRate, senderPay: senderPay)
            }

            it("parses hash and script type to Address") {
                verify(mockAddressConverter).convert(keyHash: equal(to: toAddress.keyHash), type: equal(to: toAddress.scriptType))
            }

            it("creates and sends a transaction") {
                verify(mockTransactionFeeCalculator).feeWithUnspentOutputs(value: sendingValue, feeRate: feeRate, toScriptType: equal(to: toAddress.scriptType), changeScriptType: equal(to: bip.scriptType), senderPay: senderPay)
                verify(mockPublicKeyManager).changePublicKey()
                verify(mockAddressConverter).convert(publicKey: equal(to: changePublicKey), type: equal(to: bip.scriptType))
                verify(mockTransactionBuilder).buildTransaction(value: sendingValue, unspentOutputs: equal(to: unspentOutputs), fee: selectedOutputsInfo.fee, senderPay: senderPay, toAddress: addressMatcher(toAddress), changeAddress: addressMatcher(changeAddress), lastBlockHeight: lastBlock.height)
                verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
            }
        }

        describe("#create(from:to:feeRate:signatureScriptFunction:)") {
            let unspentOutput = UnspentOutput(output: TestData.p2shTransaction.outputs[0], publicKey: TestData.pubKey(), transaction: Transaction(), blockHeight: nil)
            let signatureScriptFunction: (Data, Data) -> Data = { return $0 + $1 }
            let fee = 1000

            beforeEach {
                stub(mockTransactionFeeCalculator) { mock in
                    when(mock).fee(inputScriptType: any(), outputScriptType: any(), feeRate: any(), signatureScriptFunction: any()).thenReturn(fee)
                }
                stub(mockTransactionBuilder) { mock in
                    when(mock).buildTransaction(from: any(), to: any(), fee: any(), lastBlockHeight: any(), signatureScriptFunction: any()).thenReturn(transaction)
                }
            }

            context("when success") {
                beforeEach {
                    stub(mockTransactionFeeCalculator) { mock in
                        when(mock).fee(inputScriptType: any(), outputScriptType: any(), feeRate: any(), signatureScriptFunction: any()).thenReturn(fee)
                    }

                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try! creator.create(from: unspentOutput, to: toAddress.stringValue, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
                }

                it("parses 'to' string to Address") {
                    verify(mockAddressConverter).convert(address: toAddress.stringValue)
                }

                it("calculates fee") {
                    verify(mockTransactionFeeCalculator).fee(inputScriptType: equal(to: unspentOutput.output.scriptType), outputScriptType: equal(to: toAddress.scriptType), feeRate: feeRate, signatureScriptFunction: any())
                }

                it("creates transaction") {
                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), to: addressMatcher(toAddress), fee: fee, lastBlockHeight: lastBlock.height, signatureScriptFunction: any())
                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
                }

                it("sends transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }
            }

            context("when lastBlock is nil") {
                beforeEach {
                    stub(mockTransactionFeeCalculator) { mock in
                        when(mock).fee(inputScriptType: any(), outputScriptType: any(), feeRate: any(), signatureScriptFunction: any()).thenReturn(fee)
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }
                    stub(mockStorage) { mock in
                        when(mock.lastBlock.get).thenReturn(nil)
                    }

                    _ = try! creator.create(from: unspentOutput, to: toAddress.stringValue, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
                }

                it("builds transactions with lastBlockHeight: 0") {
                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), to: addressMatcher(toAddress), fee: fee, lastBlockHeight: 0, signatureScriptFunction: any())
                }
            }

            context("when BloomFilterManager.BloomFilterExpired error") {
                beforeEach {
                    stub(mockTransactionProcessor) { mock in
                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
                    }
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenDoNothing()
                    }

                    _ = try? creator.create(from: unspentOutput, to: toAddress.stringValue, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
                }

                it("does create transaction") {
                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), to: any(), fee: fee, lastBlockHeight: lastBlock.height, signatureScriptFunction: any())
                    verify(mockTransactionProcessor).processCreated(transaction: any())
                }

                it("does send transaction") {
                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
                }

                it("regenerates bloomfilter") {
                    verify(mockBloomFilterManager).regenerateBloomFilter()
                }
            }

            context("when other error") {
                beforeEach {
                    stub(mockTransactionSender) { mock in
                        when(mock.verifyCanSend()).thenThrow(BitcoinCoreErrors.TransactionSendError.noConnectedPeers)
                    }

                    _ = try? creator.create(from: unspentOutput, to: toAddress.stringValue, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
                }

                it("doesn't create transaction") {
                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
                }

                it("doesn't regenerate bloomfilter") {
                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
                }
            }
        }
    }
}
