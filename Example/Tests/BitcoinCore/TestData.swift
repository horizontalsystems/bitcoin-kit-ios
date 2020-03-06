import Foundation
import GRDB
@testable import BitcoinCore

class TestData {

    static var checkpoint: Checkpoint {
        Checkpoint(block: checkpointBlock, additionalBlocks: [])
    }

    static var lastCheckpoint: Checkpoint {
        Checkpoint(block: firstBlock, additionalBlocks: [])
    }

    static var checkpointBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "cec100cc".reversedData!,
                        previousBlockHeaderHash: "00000000864b744c5025331036aa4a16e9ed1cbb362908c625272150fa059b29".reversedData!,
                        merkleRoot: "70d6379650ac87eaa4ac1de27c21217b81a034a53abf156c422a538150bd80f4".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 2391008772
                ),
                height: 2016)
    }

    static var firstBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "11b10ccc".reversedData!,
                        previousBlockHeaderHash: checkpointBlock.headerHash,
                        merkleRoot: "55de0864e0b96f0dff597b1c138de187dd8c40e859b01b4671f7a92ca1b7a9b9".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 1716024842
                ),
                previousBlock: checkpointBlock)
    }

    static var secondBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "22b10ccc".reversedData!,
                        previousBlockHeaderHash: firstBlock.headerHash,
                        merkleRoot: "9a342c0615d0e5a3256f5b9a7818abecc1c8722ab3a8db8df5595c8635cc11e1".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 627458064
                ),
                previousBlock: firstBlock)
    }

    static var thirdBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "33b10ccc".reversedData!,
                        previousBlockHeaderHash: secondBlock.headerHash,
                        merkleRoot: "4848ea1ec4f1838bc0a6a243b9350d76bfeda63532b6a1cc6bae0df27aba11b3".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 3977416709
                ),
                previousBlock: secondBlock)
    }

    static var forthBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "44b10ccc".reversedData!,
                        previousBlockHeaderHash: thirdBlock.headerHash,
                        merkleRoot: "d45043107540b486cf2079a1d510bfe18053aac2446c5043a2b8eff01668426d".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 1930065423
                ),
                previousBlock: thirdBlock)
    }

    static var oldBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "01db10cc".reversedData!,
                        previousBlockHeaderHash: "0000000036f7b90238ac6b6026be5e121ac3055f19fffd69f28310a76aa4a5bc".reversedData!,
                        merkleRoot: "3bf8c518a7a1187287516da67cb96733697b1d83eb937e68ae39bd4c08e563b7".reversedData!,
                        timestamp: 1337966144,
                        bits: 486604799,
                        nonce: 1029134858
                ),
                height: 1000)
    }

    static var preCheckpointBlockHeader: BlockHeader {
        let header = BlockHeader(
                version: 536870912,
                headerHash: "00b10ccc".reversedData!,
                previousBlockHeaderHash: "00000000000003b0bfa9f11f946df6502b3fe5863cf4768dcf9e35b5fc94f9b7".reversedData!,
                merkleRoot: "99344f97da778690e2af9729a7302c6f6bd2197a1b682ebc142f7de8236a85b9".reversedData!,
                timestamp: 1530756271,
                bits: 436469756,
                nonce: 1373357969
        )
        //        header.headerHash = CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: header))
        return header
    }

    static let preCheckpointBlockHeight: Int = 1350719

    static var checkpointBlockHeader: BlockHeader {
        let header = BlockHeader(
                version: 536870912,
                headerHash: "99b10ccc".reversedData!,
                previousBlockHeaderHash: "00000000000002ac6d5c058c9932f350aeef84f6e334f4e01b40be4db537f8c2".reversedData!,
                merkleRoot: "9e172a04fc387db6f273ee96b4ef50732bb4b06e494483d182c5722afd8770b3".reversedData!,
                timestamp: 1530756778,
                bits: 436273151,
                nonce: 4053884125
        )
        //        header.headerHash = CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: header))
        return header
    }

    static var p2wpkhTransaction: FullTransaction {
        let transaction = Transaction(version: 1, lockTime: 0)
        setRandomHash(to: transaction)
        let inputs = [
            Input(
                    withPreviousOutputTxHash: Data(hex: "a6d1ce683f38a84cfd88a9d48b0ba2d7a8def00f8517e3da02c86fce6c7863d7")!, previousOutputIndex: 0,
                    script: Data(hex: "4730440220302e597d74aebcb0bf7f372be156252017af190bd586466104b079fba4b7efa7022037ebbf84e096ef3d966123a93a83586012353c1d2c11c967d21acf1c94c45df001210347235e12207d21b6093d9fd93a0df4d589a0d44252b98b2e934a8da5ab1d1654")!,
                    sequence: 4294967295
            )
        ]
        let outputs = [
            Output(withValue: 10792000, index: 0 , lockingScript: Data(hex: "00148749115073ad59a6f3587f1f9e468adedf01473f")!, type: .p2wpkh, keyHash: Data()),
            Output(withValue: 0, index: 0, lockingScript: Data(hex: "6a4c500000b919000189658af37cd16dbd16e4186ea13c5d8e1f40c5b5a0958326067dd923b8fc8f0767f62eb9a7fd57df4f3e775a96ca5b5eabf5057dff98997a3bbd011366703f5e45075f397f7f3c8465da")!, type: .p2pk, keyHash: Data()),
        ]

        return FullTransaction(header: transaction, inputs: inputs, outputs: outputs)
    }

    static var p2pkhTransaction: FullTransaction {
        let transaction = Transaction(version: 1, lockTime: 0)
        setRandomHash(to: transaction)
        let inputs = [
            Input(
                    withPreviousOutputTxHash: Data(hex: "a6d1ce683f38a84cfd88a9d48b0ba2d7a8def00f8517e3da02c86fce6c7863d7")!, previousOutputIndex: 0,
                    script: Data(hex: "4730440220302e597d74aebcb0bf7f372be156252017af190bd586466104b079fba4b7efa7022037ebbf84e096ef3d966123a93a83586012353c1d2c11c967d21acf1c94c45df001210347235e12207d21b6093d9fd93a0df4d589a0d44252b98b2e934a8da5ab1d1654")!,
                    sequence: 4294967295
            )
        ]
        let outputs = [
            Output(withValue: 10792000, index: 0 , lockingScript: Data(hex: "76a9141ec865abcb88cec71c484d4dadec3d7dc0271a7b88ac")!, type: .p2pkh, keyHash: Data()),
            Output(withValue: 0, index: 0, lockingScript: Data(hex: "76a9141ec865abcb88cec71c484d4dadec3d7dc0271a7b88ac76a9141ec865abcb88cec71c484d4dadec3d7dc0271a7b88ac")!, type: .p2pk, keyHash: Data()),
        ]

        return FullTransaction(header: transaction, inputs: inputs, outputs: outputs)
    }

    static var p2pkTransaction: FullTransaction {
        let transaction = Transaction(version: 1, lockTime: 0)
        setRandomHash(to: transaction)
        let inputs = [
            Input(
                    withPreviousOutputTxHash: Data(hex: "a6d1ce683f38a84cfd88a9d48b0ba2d7a8def00f8517e3da02c86fce6c7863d7")!, previousOutputIndex: 0,
                    script: Data(hex: "4730440220302e597d74aebcb0bf7f372be156252017af190bd586466104b079fba4b7efa7022037ebbf84e096ef3d966123a93a83586012353c1d2c11c967d21acf1c94c45df001210347235e12207d21b6093d9fd93a0df4d589a0d44252b98b2e934a8da5ab1d1654")!,
                    sequence: 4294967295
            )
        ]
        let outputs = [
            Output(withValue: 10, index: 1, lockingScript: Data(hex: "21037d56797fbe9aa506fc263751abf23bb46c9770181a6059096808923f0a64cb15ac")!, type: .p2pk, keyHash: Data()),
        ]

        return FullTransaction(header: transaction, inputs: inputs, outputs: outputs)
    }

    static var p2shTransaction: FullTransaction {
        let transaction = Transaction(version: 1, lockTime: 0)
        setRandomHash(to: transaction)
        let inputs = [
            Input(
                    withPreviousOutputTxHash: Data(hex: "a6d1ce683f38a84cfd88a9d48b0ba2d7a8def00f8517e3da02c86fce6c7863d7")!, previousOutputIndex: 0,
                    script: Data(hex: "4730440220302e597d74aebcb0bf7f372be156252017af190bd586466104b079fba4b7efa7022037ebbf84e096ef3d966123a93a83586012353c1d2c11c967d21acf1c94c45df001210347235e12207d21b6093d9fd93a0df4d589a0d44252b98b2e934a8da5ab1d1654")!,
                    sequence: 4294967295
            )
        ]
        let outputs = [
            Output(withValue: 10, index: 1, lockingScript: Data(hex: "a914bd82ef4973ebfcbc8f7cb1d540ef0503a791970b87")!, type: .p2sh, keyHash: Data()),
        ]

        return FullTransaction(header: transaction, inputs: inputs, outputs: outputs)
    }

    static func pubKey(pubKeyHash: Data = Data(hex: "1ec865abcb88cec71c484d4dadec3d7dc0271a7b")!) -> PublicKey {
        PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: pubKeyHash)
    }

    static func input(previousTransaction: Transaction, previousOutput: Output, script: Data, sequence: Int) -> Input {
        Input(withPreviousOutputTxHash: previousTransaction.dataHash, previousOutputIndex: previousOutput.index, script: script, sequence: sequence)
    }

    static func unspentOutput(output: Output) -> UnspentOutput {
        UnspentOutput(output: output, publicKey: pubKey(), transaction: Transaction(), blockHeight: nil)
    }

    private class func setRandomHash(to transaction: Transaction) {
        var bytes = Data(count: 32)
        let _ = bytes.withUnsafeMutableBytes {
            (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
            SecRandomCopyBytes(kSecRandomDefault, 32, mutableBytes)
        }

        transaction.dataHash = bytes
    }

}

func randomBytes(length: Int) -> Data {
    var bytes = Data(count: length)
    let _ = bytes.withUnsafeMutableBytes { mutableBytes -> Int32 in
        SecRandomCopyBytes(kSecRandomDefault, length, mutableBytes.baseAddress!.assumingMemoryBound(to: UInt8.self))
    }

    return bytes
}
