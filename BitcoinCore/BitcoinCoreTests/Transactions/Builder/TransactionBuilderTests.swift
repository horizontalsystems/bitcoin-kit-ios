import XCTest
import Cuckoo
import Nimble
import Quick
@testable import BitcoinCore


class TransactionBuilderTests: QuickSpec {
    override func spec() {
        let mockInputSigner = MockIInputSigner()
        let mockScriptBuilder = MockIScriptBuilder()
        let mockFactory = MockIFactory()

        let toAddressPKH = LegacyAddress(type: .pubKeyHash, keyHash: randomBytes(length: 32), base58: "toAddressPKH")
        let toAddressSH = LegacyAddress(type: .scriptHash, keyHash: randomBytes(length: 32), base58: "toAddressSH")
        let changeAddressPKH = LegacyAddress(type: .pubKeyHash, keyHash: randomBytes(length: 32), base58: "changeAddressPKH")
        let changeAddressWPKH = SegWitAddress(type: .pubKeyHash, keyHash: randomBytes(length: 32), bech32: "changeAddressWPKH", version: 0)

        let signatureData = [randomBytes(length: 72), randomBytes(length: 64)]
        let sendingValue = 100_000_000
        let fee = 1000

        var builder: TransactionBuilder!

        beforeEach {
            stub(mockFactory) { mock in
                when(mock).transaction(version: 1, lockTime: 0).thenReturn(Transaction(version: 1, lockTime: 0))
                when(mock).output(withValue: any(), index: any(), lockingScript: any(), type: any(), address: any(), keyHash: equal(to: toAddressPKH.keyHash), publicKey: isNil()).thenReturn(self.output(from: toAddressPKH))
                when(mock).output(withValue: any(), index: any(), lockingScript: any(), type: any(), address: any(), keyHash: equal(to: changeAddressPKH.keyHash), publicKey: isNil()).thenReturn(self.output(from: changeAddressPKH))
                when(mock).output(withValue: any(), index: any(), lockingScript: any(), type: any(), address: any(), keyHash: equal(to: toAddressSH.keyHash), publicKey: isNil()).thenReturn(self.output(from: toAddressSH))
                when(mock).output(withValue: any(), index: any(), lockingScript: any(), type: any(), address: any(), keyHash: equal(to: changeAddressWPKH.keyHash), publicKey: isNil()).thenReturn(self.output(from: changeAddressWPKH))
            }

            builder = TransactionBuilder(inputSigner: mockInputSigner, scriptBuilder: mockScriptBuilder, factory: mockFactory)
        }

        afterEach {
            reset(mockInputSigner, mockScriptBuilder, mockFactory)
        }

        describe("#buildTransaction") {
            var unspentOutput: UnspentOutput!
            var inputToSign: InputToSign!
            var fullTransaction: FullTransaction!

            beforeEach {
                unspentOutput = UnspentOutput(
                        output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2pkh),
                        publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                        transaction: Transaction(),
                        blockHeight: 1000
                )
                inputToSign = InputToSign(
                        input: Input(withPreviousOutputTxHash: randomBytes(length: 32), previousOutputIndex: 0, script: Data(), sequence: 0),
                        previousOutput: unspentOutput.output, previousOutputPublicKey: unspentOutput.publicKey
                )

                stub(mockFactory) { mock in
                    when(mock).inputToSign(withPreviousOutput: equal(to: unspentOutput), script: any(), sequence: any()).thenReturn(inputToSign)
                }
                stub(mockScriptBuilder) { mock in
                    when(mock).lockingScript(for: any()).thenReturn(Data())
                }
                stub(mockInputSigner) { mock in
                    when(mock).sigScriptData(transaction: any(), inputsToSign: any(), outputs: any(), index: any()).thenReturn(signatureData)
                }
            }

            afterEach {
                unspentOutput = nil
                inputToSign = nil
            }

            context("when unspentOutput is P2PKH, senderPay is true, addChangeOutput is true") {
                beforeEach {
                    fullTransaction = try! builder.buildTransaction(value: sendingValue, unspentOutputs: [unspentOutput], fee: fee, senderPay: true, toAddress: toAddressPKH, changeAddress: changeAddressPKH)
                }

                it("adds input from unspentOutput") {
                    verify(mockFactory).inputToSign(withPreviousOutput: equal(to: unspentOutput), script: any(), sequence: any())
                    expect(fullTransaction.inputs.count).to(equal(1))
                    expect(fullTransaction.inputs[0].previousOutputTxHash).to(equal(inputToSign.input.previousOutputTxHash))
                    expect(fullTransaction.inputs[0].previousOutputIndex).to(equal(inputToSign.input.previousOutputIndex))
                }

                it("adds 1 output for toAddress") {
                    verify(mockFactory).output(withValue: sendingValue, index: 0, lockingScript: any(), type: equal(to: ScriptType.p2pkh), address: toAddressPKH.stringValue, keyHash: equal(to: toAddressPKH.keyHash), publicKey: isNil())
                    expect(fullTransaction.outputs.count).to(equal(2))

                    let toOutput = self.output(from: toAddressPKH)
                    expect(fullTransaction.outputs[0].keyHash).to(equal(toOutput.keyHash))
                    expect(fullTransaction.outputs[0].value).to(equal(toOutput.value))
                }

                it("adds 1 output for changeAddress") {
                    let changeValue = unspentOutput.output.value - sendingValue - fee
                    verify(mockFactory).output(withValue: changeValue, index: 1, lockingScript: any(), type: equal(to: ScriptType.p2pkh), address: changeAddressPKH.stringValue, keyHash: equal(to: changeAddressPKH.keyHash), publicKey: isNil())

                    let changeOutput = self.output(from: changeAddressPKH)
                    expect(fullTransaction.outputs[1].keyHash).to(equal(changeOutput.keyHash))
                    expect(fullTransaction.outputs[1].value).to(equal(changeOutput.value))
                }

                it("signs the input") {
                    verify(mockInputSigner).sigScriptData(transaction: any(), inputsToSign: equal(to: [inputToSign]), outputs: equal(to: [self.output(from: toAddressPKH), self.output(from: changeAddressPKH)]), index: 0)
                    expect(fullTransaction.inputs[0].signatureScript).to(equal(OpCode.push(signatureData[0]) + OpCode.push(signatureData[1])))
                }

                it("sets transaction properties") {
                    expect(fullTransaction.header.status).to(equal(TransactionStatus.new))
                    expect(fullTransaction.header.isMine).to(beTrue())
                    expect(fullTransaction.header.isOutgoing).to(beTrue())
                    expect(fullTransaction.header.segWit).to(beFalse())
                }
            }

            context("when changeAddress is nil") {
                beforeEach {
                    fullTransaction = try! builder.buildTransaction(value: sendingValue, unspentOutputs: [unspentOutput], fee: fee, senderPay: true, toAddress: toAddressPKH, changeAddress: nil)
                }

                it("adds 1 output for toAddress") {
                    verify(mockFactory).output(withValue: sendingValue, index: 0, lockingScript: any(), type: equal(to: toAddressPKH.scriptType), address: toAddressPKH.stringValue, keyHash: equal(to: toAddressPKH.keyHash), publicKey: isNil())
                }

                it("doesn't add 1 output for changeAddress") {
                    let changeValue = unspentOutput.output.value - sendingValue - fee
                    verify(mockFactory, never()).output(withValue: changeValue, index: 1, lockingScript: any(), type: equal(to: changeAddressPKH.scriptType), address: changeAddressPKH.stringValue, keyHash: equal(to: changeAddressPKH.keyHash), publicKey: isNil())
                    expect(fullTransaction.outputs.count).to(equal(1))
                }
            }

            context("when senderPay is false") {
                context("value is valid") {
                    beforeEach {
                        fullTransaction = try! builder.buildTransaction(value: sendingValue, unspentOutputs: [unspentOutput], fee: fee, senderPay: false, toAddress: toAddressPKH, changeAddress: changeAddressPKH)
                    }

                    it("subtracts fee from value in receiver output") {
                        let receivedValue = sendingValue - fee
                        verify(mockFactory).output(withValue: receivedValue, index: 0, lockingScript: any(), type: equal(to: toAddressPKH.scriptType), address: toAddressPKH.stringValue, keyHash: equal(to: toAddressPKH.keyHash), publicKey: isNil())
                    }

                    it("puts the remained value in change output") {
                        let changeValue = unspentOutput.output.value - sendingValue
                        verify(mockFactory).output(withValue: changeValue, index: 1, lockingScript: any(), type: equal(to: changeAddressPKH.scriptType), address: changeAddressPKH.stringValue, keyHash: equal(to: changeAddressPKH.keyHash), publicKey: isNil())
                    }
                }

                context("value less than fee") {
                    it("throws feeMoreThanValue exception") {
                        do {
                            fullTransaction = try builder.buildTransaction(value: fee - 1, unspentOutputs: [unspentOutput], fee: fee, senderPay: false, toAddress: toAddressPKH, changeAddress: changeAddressPKH)
                            fail("Expecting an exception")
                        } catch let error as TransactionBuilder.BuildError {
                            expect(error).to(equal(TransactionBuilder.BuildError.feeMoreThanValue))
                        } catch {
                            fail("Unexpected exception")
                        }
                    }
                }
            }

            context("when toAddress and/or changeAddress types are P2SH or P2WPKH") {
                beforeEach {
                    fullTransaction = try! builder.buildTransaction(value: sendingValue, unspentOutputs: [unspentOutput], fee: fee, senderPay: true, toAddress: toAddressSH, changeAddress: changeAddressWPKH)
                }

                it("generates outputs considering address types") {
                    verify(mockFactory).output(withValue: any(), index: 0, lockingScript: any(), type: equal(to: ScriptType.p2sh), address: toAddressSH.stringValue, keyHash: equal(to: toAddressSH.keyHash), publicKey: isNil())
                    verify(mockFactory).output(withValue: any(), index: 1, lockingScript: any(), type: equal(to: ScriptType.p2wpkh), address: changeAddressWPKH.stringValue, keyHash: equal(to: changeAddressWPKH.keyHash), publicKey: isNil())
                }
            }

            context("when unspent output is P2WPKH") {
                beforeEach {
                    unspentOutput = UnspentOutput(
                            output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2wpkh),
                            publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                            transaction: Transaction(),
                            blockHeight: 1000
                    )
                    inputToSign = InputToSign(
                            input: Input(withPreviousOutputTxHash: randomBytes(length: 32), previousOutputIndex: 0, script: Data(), sequence: 0),
                            previousOutput: unspentOutput.output, previousOutputPublicKey: unspentOutput.publicKey
                    )
                    stub(mockFactory) { mock in
                        when(mock).inputToSign(withPreviousOutput: equal(to: unspentOutput), script: any(), sequence: any()).thenReturn(inputToSign)
                    }

                    fullTransaction = try! builder.buildTransaction(value: sendingValue, unspentOutputs: [unspentOutput], fee: fee, senderPay: true, toAddress: toAddressPKH, changeAddress: changeAddressPKH)
                }

                it("sets P2WPKH unlocking script to witnessData") {
                    expect(fullTransaction.inputs[0].witnessData).to(equal(signatureData))
                }

                it("sets empty data to signatureScript") {
                    expect(fullTransaction.inputs[0].signatureScript).to(equal(Data()))
                }

                it("sets segWit flag to true") {
                    expect(fullTransaction.header.segWit).to(beTrue())
                }
            }

            context("when unspent output is P2WPKH(SH") {
                beforeEach {
                    unspentOutput = UnspentOutput(
                            output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2wpkhSh),
                            publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                            transaction: Transaction(),
                            blockHeight: 1000
                    )
                    inputToSign = InputToSign(
                            input: Input(withPreviousOutputTxHash: randomBytes(length: 32), previousOutputIndex: 0, script: Data(), sequence: 0),
                            previousOutput: unspentOutput.output, previousOutputPublicKey: unspentOutput.publicKey
                    )
                    stub(mockFactory) { mock in
                        when(mock).inputToSign(withPreviousOutput: equal(to: unspentOutput), script: any(), sequence: any()).thenReturn(inputToSign)
                    }

                    fullTransaction = try! builder.buildTransaction(value: sendingValue, unspentOutputs: [unspentOutput], fee: fee, senderPay: true, toAddress: toAddressPKH, changeAddress: changeAddressPKH)
                }

                it("sets P2WPKH unlocking script to witnessData") {
                    expect(fullTransaction.inputs[0].witnessData).to(equal(signatureData))
                }

                it("sets P2SH unlocking script to signatureScript") {
                    let script = OpCode.push(OpCode.scriptWPKH(unspentOutput.publicKey.keyHash))
                    expect(fullTransaction.inputs[0].signatureScript).to(equal(script))
                }

                it("sets segWit flag to true") {
                    expect(fullTransaction.header.segWit).to(beTrue())
                }
            }

            context("when unspent output is not supported") {
                it("throws notSupportedScriptType exception") {
                    unspentOutput = UnspentOutput(
                            output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2sh),
                            publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                            transaction: Transaction(),
                            blockHeight: 1000
                    )
                    inputToSign = InputToSign(
                            input: Input(withPreviousOutputTxHash: randomBytes(length: 32), previousOutputIndex: 0, script: Data(), sequence: 0),
                            previousOutput: unspentOutput.output, previousOutputPublicKey: unspentOutput.publicKey
                    )
                    stub(mockFactory) { mock in
                        when(mock).inputToSign(withPreviousOutput: equal(to: unspentOutput), script: any(), sequence: any()).thenReturn(inputToSign)
                    }

                    do {
                        fullTransaction = try builder.buildTransaction(value: sendingValue, unspentOutputs: [unspentOutput], fee: fee, senderPay: true, toAddress: toAddressPKH, changeAddress: changeAddressPKH)
                        fail("Expecting an exception")
                    } catch let error as TransactionBuilder.BuildError {
                        expect(error).to(equal(TransactionBuilder.BuildError.notSupportedScriptType))
                    } catch {
                        fail("Unexpected exception")
                    }
                }
            }
        }

        describe("#buildTransaction(P2SH)") {
            let signatureScript = randomBytes(length: 100)
            var signatureScriptFunctionCalled = false
            let signatureScriptFunction: ((Data, Data) -> Data) = { (signature: Data, publicKey: Data) in
                XCTAssertEqual(signature, signatureData[0])
                XCTAssertEqual(publicKey, signatureData[1])
                signatureScriptFunctionCalled = true
                return signatureScript
            }

            var unspentOutput: UnspentOutput!
            var inputToSign: InputToSign!
            var fullTransaction: FullTransaction!

            beforeEach {
                unspentOutput = UnspentOutput(
                        output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2sh),
                        publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                        transaction: Transaction(),
                        blockHeight: 1000
                )
                inputToSign = InputToSign(
                        input: Input(withPreviousOutputTxHash: randomBytes(length: 32), previousOutputIndex: 0, script: Data(), sequence: 0),
                        previousOutput: unspentOutput.output, previousOutputPublicKey: unspentOutput.publicKey
                )

                stub(mockFactory) { mock in
                    when(mock).inputToSign(withPreviousOutput: equal(to: unspentOutput), script: any(), sequence: any()).thenReturn(inputToSign)
                }
                stub(mockScriptBuilder) { mock in
                    when(mock).lockingScript(for: any()).thenReturn(Data())
                }
                stub(mockInputSigner) { mock in
                    when(mock).sigScriptData(transaction: any(), inputsToSign: any(), outputs: any(), index: any()).thenReturn(signatureData)
                }
            }

            afterEach {
                unspentOutput = nil
                inputToSign = nil
                signatureScriptFunctionCalled = false
            }

            context("when fee is valid, unspent output type is P2SH") {
                beforeEach {
                    fullTransaction = try! builder.buildTransaction(from: unspentOutput, to: toAddressPKH, fee: fee, signatureScriptFunction: signatureScriptFunction)
                }


                it("adds input from unspentOutput") {
                    verify(mockFactory).inputToSign(withPreviousOutput: equal(to: unspentOutput), script: any(), sequence: any())
                    expect(fullTransaction.inputs.count).to(equal(1))
                    expect(fullTransaction.inputs[0].previousOutputTxHash).to(equal(inputToSign.input.previousOutputTxHash))
                    expect(fullTransaction.inputs[0].previousOutputIndex).to(equal(inputToSign.input.previousOutputIndex))
                }

                it("adds 1 output for toAddress") {
                    verify(mockFactory).output(withValue: unspentOutput.output.value - fee, index: 0, lockingScript: any(), type: equal(to: ScriptType.p2pkh), address: toAddressPKH.stringValue, keyHash: equal(to: toAddressPKH.keyHash), publicKey: isNil())
                    expect(fullTransaction.outputs.count).to(equal(1))

                    let toOutput = self.output(from: toAddressPKH)
                    expect(fullTransaction.outputs[0].keyHash).to(equal(toOutput.keyHash))
                    expect(fullTransaction.outputs[0].value).to(equal(toOutput.value))
                }

                it("signs the input") {
                    verify(mockInputSigner).sigScriptData(transaction: any(), inputsToSign: equal(to: [inputToSign]), outputs: equal(to: [self.output(from: toAddressPKH)]), index: 0)
                    expect(fullTransaction.inputs[0].signatureScript).to(equal(signatureScript))
                    expect(signatureScriptFunctionCalled).to(beTrue())
                }

                it("sets transaction properties") {
                    expect(fullTransaction.header.status).to(equal(TransactionStatus.new))
                    expect(fullTransaction.header.isMine).to(beTrue())
                    expect(fullTransaction.header.isOutgoing).to(beFalse())
                    expect(fullTransaction.header.segWit).to(beFalse())
                }
            }

            context("when fee is less than value") {
                it("throws feeMoreThanValue exception") {
                    do {
                        fullTransaction = try builder.buildTransaction(from: unspentOutput, to: toAddressPKH, fee: unspentOutput.output.value + 1, signatureScriptFunction: signatureScriptFunction)
                        fail("Expecting an exception")
                    } catch let error as TransactionBuilder.BuildError {
                        expect(error).to(equal(TransactionBuilder.BuildError.feeMoreThanValue))
                    } catch {
                        fail("Unexpected exception")
                    }
                }
            }

            context("when unspent output type is not P2SH") {
                it("throws feeMoreThanValue exception") {
                    unspentOutput = UnspentOutput(
                            output: Output(withValue: 200_000_000, index: 0, lockingScript: randomBytes(length: 32), type: .p2wsh),
                            publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: randomBytes(length: 32)),
                            transaction: Transaction(),
                            blockHeight: 1000
                    )

                    do {
                        fullTransaction = try builder.buildTransaction(from: unspentOutput, to: toAddressPKH, fee: fee, signatureScriptFunction: signatureScriptFunction)
                        fail("Expecting an exception")
                    } catch let error as TransactionBuilder.BuildError {
                        expect(error).to(equal(TransactionBuilder.BuildError.notSupportedScriptType))
                    } catch {
                        fail("Unexpected exception")
                    }
                }
            }
        }
    }

    func output(from address: Address) -> Output {
        return Output(withValue: 0, index: 0, lockingScript: Data(), keyHash: address.keyHash)
    }

}
