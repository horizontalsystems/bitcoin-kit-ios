import BitcoinCore
import Foundation
import OpenSslKit

class QuorumParser: IQuorumParser {
    let hasher: IDashHasher

    init(hasher: IDashHasher) {
        self.hasher = hasher
    }

    func parse(byteStream: ByteStream) -> Quorum {
        let versionData = byteStream.read(Data.self, count: 2)
        let version = versionData.to(type: UInt16.self).littleEndian

        let typeWithQuorumHash = byteStream.read(Data.self, count: 33)
        let type = typeWithQuorumHash[0]
        let quorumHash = typeWithQuorumHash.subdata(in: Range(uncheckedBounds: (lower: 1, upper: 33)))

        var quorumIndexData: Data?
        var quorumIndex: UInt16?
        if version == 2 { // read v2 quorumIndex
            let indexData = byteStream.read(Data.self, count: 2)
            quorumIndex = indexData.to(type: UInt16.self).littleEndian
            quorumIndexData = indexData
        }

        let signerSizeVarInt = byteStream.read(VarInt.self)
        let signerSize = Int(signerSizeVarInt.underlyingValue)

        let signers = byteStream.read(Data.self, count: (signerSize + 7) / 8)

        let validMemberSizeVarInt = byteStream.read(VarInt.self)
        let validMemberSize = Int(validMemberSizeVarInt.underlyingValue)

        let members = byteStream.read(Data.self, count: (validMemberSize + 7) / 8)

        let quorumPublicKey = byteStream.read(Data.self, count: 48)
        let quorumVvecHash = byteStream.read(Data.self, count: 32)
        let quorumSig = byteStream.read(Data.self, count: 96)
        let sig = byteStream.read(Data.self, count: 96)


        var data = versionData +
                type +
                quorumHash
        if let index = quorumIndexData {
            data += index
        }
        data += signerSizeVarInt.data +
                signers +
                validMemberSizeVarInt.data +
                members +
                quorumPublicKey +
                quorumVvecHash +
                quorumSig +
                sig
        let hash = hasher.hash(data: data)
        return Quorum(hash: hash, version: version, type: type, quorumHash: quorumHash, typeWithQuorumHash: typeWithQuorumHash, quorumIndex: quorumIndex, signers: signers, validMembers: members, quorumPublicKey: quorumPublicKey, quorumVvecHash: quorumVvecHash, quorumSig: quorumSig, sig: sig)
    }

}
