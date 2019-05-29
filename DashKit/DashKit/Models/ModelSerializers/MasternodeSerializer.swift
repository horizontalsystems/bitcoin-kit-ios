class MasternodeSerializer: IMasternodeSerializer {

    func serialize(masternode: Masternode) -> Data {
        var data = Data()
        data += masternode.proRegTxHash
        data += masternode.confirmedHash
        data += masternode.ipAddress
        data += Data(from: masternode.port)

        data += masternode.pubKeyOperator
        data += masternode.keyIDVoting
        data += Data([masternode.isValid ? 0x01 : 0x00])

        return data
    }

}
