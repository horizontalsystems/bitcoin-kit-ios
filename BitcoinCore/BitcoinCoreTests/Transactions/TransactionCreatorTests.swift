//import XCTest
//import Cuckoo
//import Nimble
//import Quick
//@testable import BitcoinCore
//
//class TransactionCreatorTests: QuickSpec {
//    override func spec() {
//        let mockTransactionBuilder = MockITransactionBuilder()
//        let mockTransactionProcessor = MockITransactionProcessor()
//        let mockTransactionFeeCalculator = MockITransactionFeeCalculator()
//        let mockTransactionSender = MockITransactionSender()
//        let mockBloomFilterManager = MockIBloomFilterManager()
//        let mockAddressConverter = MockIAddressConverter()
//        let mockPublicKeyManager = MockIPublicKeyManager()
//
//        let transaction = TestData.p2pkhTransaction
//        let changePubKey = TestData.pubKey()
//
//        let toAddressPKH = LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "d50bf226c9ff3bcf06f13d8ca129f24bedeef594")!, base58: "mzwSXvtPs7MFbW2ysNA4Gw3P2KjrcEWaE5")
//        let toAddressSH = LegacyAddress(type: .scriptHash, keyHash: Data(hex: "43922a3f1dc4569f9eccce9a71549d5acabbc0ca")!, base58: toAddressSH)
//        let toAddressWPKH = SegWitAddress(type: .pubKeyHash, keyHash: Data(hex: "43922a3f1dc4569f9eccce9a71549d5acabbc0ca")!, bech32: "bcrt1qsay3z5rn44v6du6c0u0eu352mm0sz3el0f0cs2", version: 0)
//        let changeAddressPKH = LegacyAddress(type: .pubKeyHash, keyHash: changePubKey.keyHash, base58: changeAddressPKH)
//
//
//        let sendingValue = 100_000_000
//
//        var unspentOutputs: [UnspentOutput]!
//        var selectedOutputsInfo: SelectedUnspentOutputInfo!
//
//        var transactionCreator: TransactionCreator!
//
//        beforeEach {
//            unspentOutputs = [
//                UnspentOutput(
//                    output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2pkh),
//                    publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
//                    transaction: Transaction(),
//                    blockHeight: 1000
//                )
//            ]
//            selectedOutputsInfo = SelectedUnspentOutputInfo(unspentOutputs: unspentOutputs, totalValue: 100_000_000, fee: 1000, addChangeOutput: true)
//
//            stub(mockTransactionFeeCalculator) { mock in
//                when(mock).feeWithUnspentOutputs(value: sendingValue, feeRate: any(), toScriptType: any(), changeScriptType: any(), senderPay: any()).thenReturn(selectedOutputsInfo)
//            }
//
//            stub(mockAddressConverter) { mock in
//                when(mock.convert(address: toAddressPKH)).thenReturn(LegacyAddress(type: .pubKeyHash, keyHash: Data(hex: "d50bf226c9ff3bcf06f13d8ca129f24bedeef594")!, base58: "mzwSXvtPs7MFbW2ysNA4Gw3P2KjrcEWaE5"))
//                when(mock.convert(address: toAddressSH)).thenReturn(LegacyAddress(type: .scriptHash, keyHash: Data(hex: "43922a3f1dc4569f9eccce9a71549d5acabbc0ca")!, base58: toAddressSH))
//                when(mock.convert(address: toAddressWPKH)).thenReturn(SegWitAddress(type: .pubKeyHash, keyHash: Data(hex: "43922a3f1dc4569f9eccce9a71549d5acabbc0ca")!, bech32: "bcrt1qsay3z5rn44v6du6c0u0eu352mm0sz3el0f0cs2", version: 0))
//                when(mock.convert(address: changePubKeyAddress)).thenReturn(LegacyAddress(type: .pubKeyHash, keyHash: changePubKey.keyHash, base58: changePubKeyAddress))
//                when(mock.convert(publicKey: equal(to: changePubKey), type: equal(to: .p2pkh))).thenReturn(LegacyAddress(type: .pubKeyHash, keyHash: changePubKey.keyHash, base58: changePubKeyAddress))
//            }
//
//
//        }
//
//        afterEach {
//            reset(mockTransactionBuilder, mockTransactionProcessor, mockTransactionFeeCalculator, mockTransactionSender, mockBloomFilterManager, mockAddressConverter, mockPublicKeyManager)
//            transactionCreator = nil
//        }
//
//        describe("#create(to:value:feeRate:senderPay:)") {
//            beforeEach {
//                stub(mockTransactionBuilder) { mock in
//                    when(mock.buildTransaction(value: any(), unspentOutputs: any(), fee: any(), senderPay: any(), toAddress: any(), changeAddress: any())).thenReturn(transaction)
//                }
//                stub(mockTransactionProcessor) { mock in
//                    when(mock.processCreated(transaction: any())).thenDoNothing()
//                }
//                stub(mockTransactionSender) { mock in
//                    when(mock.send(pendingTransaction: any())).thenDoNothing()
//                }
//                stub(mockBloomFilterManager) { mock in
//                    when(mock.regenerateBloomFilter()).thenDoNothing()
//                }
//
//                transactionCreator = TransactionCreator(
//                        transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, transactionSender: mockTransactionSender, transactionFeeCalculator: mockTransactionFeeCalculator,
//                        bloomFilterManager: mockBloomFilterManager, addressConverter: mockAddressConverter, publicKeyManager: mockPublicKeyManager, bip: .bip44)
//            }
//
//            context("when BloomFilterManager.BloomFilterExpired error") {
//                beforeEach {
//                    stub(mockTransactionProcessor) { mock in
//                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
//                    }
//                    stub(mockTransactionSender) { mock in
//                        when(mock.verifyCanSend()).thenDoNothing()
//                    }
//
//                    _ = try? transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false)
//                }
//
//                it("does create transaction") {
//                    verify(mockTransactionBuilder).buildTransaction(value: 0, unspentOutputs: equal(to: unspentOutputs), fee: selectedOutputsInfo.fee, senderPay: any(), toAddress: any(), changeAddress: nil)
//                    verify(mockTransactionProcessor).processCreated(transaction: any())
//                }
//
//                it("does send transaction") {
//                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
//                }
//
//                it("regenerates bloomfilter") {
//                    verify(mockBloomFilterManager).regenerateBloomFilter()
//                }
//            }
//
//            context("when other error") {
//                beforeEach {
//                    stub(mockTransactionSender) { mock in
//                        when(mock.verifyCanSend()).thenThrow(BitcoinCoreErrors.TransactionSendError.noConnectedPeers)
//                    }
//
//                    _ = try? transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false)
//                }
//
//                it("doesn't create transaction") {
//                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
//                }
//
//                it("doesn't regenerate bloomfilter") {
//                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
//                }
//            }
//
//            context("when success") {
//                beforeEach {
//                    stub(mockTransactionSender) { mock in
//                        when(mock.verifyCanSend()).thenDoNothing()
//                    }
//                    _ = try! transactionCreator.create(to: "", value: 0, feeRate: 0, senderPay: false)
//                }
//
//                it("creates transaction") {
//                    verify(mockTransactionBuilder).buildTransaction(value: 0, unspentOutputs: equal(to: unspentOutputs), fee: selectedOutputsInfo.fee, senderPay: any(), toAddress: any(), changeAddress: nil)
//                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
//                }
//
//                it("sends transaction") {
//                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
//                }
//            }
//        }
//
//        describe("#create(from:to:feeRate:signatureScriptFunction:)") {
//            let unspentOutput = UnspentOutput(output: TestData.p2shTransaction.outputs[0], publicKey: TestData.pubKey(), transaction: Transaction(), blockHeight: nil)
//            let signatureScriptFunction: (Data, Data) -> Data = { return $0 + $1 }
//            let fee = 1000
//
//            beforeEach {
//                stub(mockTransactionBuilder) { mock in
//                    when(mock.buildTransaction(from: any(), to: any(), fee: any(), signatureScriptFunction: any())).thenReturn(transaction)
//                }
//                stub(mockTransactionProcessor) { mock in
//                    when(mock.processCreated(transaction: any())).thenDoNothing()
//                }
//                stub(mockTransactionSender) { mock in
//                    when(mock.send(pendingTransaction: any())).thenDoNothing()
//                }
//                stub(mockBloomFilterManager) { mock in
//                    when(mock.regenerateBloomFilter()).thenDoNothing()
//                }
//
//                transactionCreator = TransactionCreator(transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, transactionSender: mockTransactionSender, bloomFilterManager: mockBloomFilterManager)
//            }
//
//            context("when BloomFilterManager.BloomFilterExpired error") {
//                beforeEach {
//                    stub(mockTransactionProcessor) { mock in
//                        when(mock.processCreated(transaction: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
//                    }
//                    stub(mockTransactionSender) { mock in
//                        when(mock.verifyCanSend()).thenDoNothing()
//                    }
//
//                    _ = try? transactionCreator.create(from: unspentOutput, to: toAddressPKH, feeRate: 0, signatureScriptFunction: signatureScriptFunction)
//                }
//
//                it("does create transaction") {
//                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), to: , fee: fee, signatureScriptFunction: any())
//                    verify(mockTransactionProcessor).processCreated(transaction: any())
//                }
//
//                it("does send transaction") {
//                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
//                }
//
//                it("regenerates bloomfilter") {
//                    verify(mockBloomFilterManager).regenerateBloomFilter()
//                }
//            }
//
//            context("when other error") {
//                beforeEach {
//                    stub(mockTransactionSender) { mock in
//                        when(mock.verifyCanSend()).thenThrow(BitcoinCoreErrors.TransactionSendError.noConnectedPeers)
//                    }
//
//                    _ = try? transactionCreator.create(from: unspentOutput, to: "", feeRate: 0, signatureScriptFunction: signatureScriptFunction)
//                }
//
//                it("doesn't create transaction") {
//                    verify(mockTransactionProcessor, never()).processCreated(transaction: any())
//                }
//
//                it("doesn't regenerate bloomfilter") {
//                    verify(mockBloomFilterManager, never()).regenerateBloomFilter()
//                }
//            }
//
//            context("when success") {
//                beforeEach {
//                    stub(mockTransactionSender) { mock in
//                        when(mock.verifyCanSend()).thenDoNothing()
//                    }
//
//                    _ = try! transactionCreator.create(from: unspentOutput, to: "", feeRate: 0, signatureScriptFunction: signatureScriptFunction)
//                }
//
//                it("creates transaction") {
//                    verify(mockTransactionBuilder).buildTransaction(from: equal(to: unspentOutput), to: "", feeRate: 0, signatureScriptFunction: any())
//                    verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
//                }
//
//                it("sends transaction") {
//                    verify(mockTransactionSender).send(pendingTransaction: equal(to: transaction))
//                }
//            }
//        }
//    }
//}
