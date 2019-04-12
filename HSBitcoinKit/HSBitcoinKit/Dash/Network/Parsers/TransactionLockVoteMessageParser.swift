import HSCryptoKit

class TransactionLockVoteMessageParser: MessageParser {
    override var id: String { return "txlvote" }

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

        let txHash = byteStream.read(Data.self, count: 32)
        let outpoint = Outpoint(byteStream: byteStream)
        let outpointMasternode = Outpoint(byteStream: byteStream)
        let quorumModifierHash = byteStream.read(Data.self, count: 32)
        let masternodeProTxHash = byteStream.read(Data.self, count: 32)
        let vchMasternodeSignature = byteStream.read(Data.self, count: 96)

        let hash = CryptoKit.sha256sha256(request.prefix(168))

        return TransactionLockVoteMessage(txHash: txHash,
                outpoint: outpoint,
                outpointMasternode: outpointMasternode,
                quorumModifierHash: quorumModifierHash,
                masternodeProTxHash: masternodeProTxHash,
                vchMasternodeSignature: vchMasternodeSignature, hash: hash)
    }

}
