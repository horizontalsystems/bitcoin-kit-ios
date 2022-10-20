import BitcoinCore
import OpenSslKit

class TransactionLockVoteMessageParser: IMessageParser {
    var id: String { return "txlvote" }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let txHash = byteStream.read(Data.self, count: 32)
        let outpoint = Outpoint(byteStream: byteStream)
        let outpointMasternode = Outpoint(byteStream: byteStream)
        let quorumModifierHash = byteStream.read(Data.self, count: 32)
        let masternodeProTxHash = byteStream.read(Data.self, count: 32)
        let signatureLength = byteStream.read(VarInt.self)
        let vchMasternodeSignature = byteStream.read(Data.self, count: Int(signatureLength.underlyingValue))

        let hash = OpenSslKit.Kit.sha256sha256(data.prefix(168))

        return TransactionLockVoteMessage(txHash: txHash,
                outpoint: outpoint,
                outpointMasternode: outpointMasternode,
                quorumModifierHash: quorumModifierHash,
                masternodeProTxHash: masternodeProTxHash,
                vchMasternodeSignature: vchMasternodeSignature, hash: hash)
    }

}
