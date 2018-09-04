//
//  VersionMessage.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/02/11.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

/// When a node creates an outgoing connection, it will immediately advertise its version.
/// The remote node will respond with its version. No further communication is possible until both peers have exchanged their version.
struct VersionMessage: IMessage{
    /// Identifies protocol version being used by the node
    let version: Int32
    /// bitfield of features to be enabled for this connection
    let services: UInt64
    /// standard UNIX timestamp in seconds
    let timestamp: Int64
    // The network address of the node receiving this message
    let yourAddress: NetworkAddress
    /* Fields below require version ≥ 106 */
    /// The network address of the node emitting this message
    let myAddress: NetworkAddress?
    /// Node random nonce, randomly generated every time a version packet is sent. This nonce is used to detect connections to self.
    let nonce: UInt64?
    /// User Agent (0x00 if string is 0 bytes long)
    let userAgent: VarString?
    // The last block received by the emitting node
    let startHeight: Int32?
    /* Fields below require version ≥ 70001 */
    /// Whether the remote peer should announce relayed transactions or not, see BIP 0037
    let relay: Bool?

    init(version: Int32, services: UInt64, timestamp: Int64, yourAddress: NetworkAddress, myAddress: NetworkAddress?, nonce: UInt64?, userAgent: VarString?, startHeight: Int32?, relay: Bool?) {
        self.version = version
        self.services = services
        self.timestamp = timestamp
        self.yourAddress = yourAddress
        self.myAddress = myAddress
        self.nonce = nonce
        self.userAgent = userAgent
        self.startHeight = startHeight
        self.relay = relay
    }

    init(_ data: Data) {
        let byteStream = ByteStream(data)

        version = byteStream.read(Int32.self)
        services = byteStream.read(UInt64.self)
        timestamp = byteStream.read(Int64.self)
        yourAddress = NetworkAddress(byteStream)
        if byteStream.availableBytes == 0 {
            myAddress = nil
            nonce = nil
            userAgent = nil
            startHeight = nil
            relay = nil
            return
        }
        myAddress = NetworkAddress(byteStream)
        nonce = byteStream.read(UInt64.self)
        userAgent = byteStream.read(VarString.self)
        startHeight = byteStream.read(Int32.self)
        if byteStream.availableBytes == 0 {
            relay = nil
            return
        }
        relay = byteStream.read(Bool.self)
    }

    func serialized() -> Data {
        var data = Data()
        data += version.littleEndian
        data += services.littleEndian
        data += timestamp.littleEndian
        data += yourAddress.serialized()
        data += myAddress?.serialized() ?? Data(count: 26)
        data += nonce?.littleEndian ?? UInt64(0)
        data += userAgent?.serialized() ?? Data([UInt8(0x00)])
        data += startHeight?.littleEndian ?? Int32(0)
        data += relay ?? false
        return data
    }

}
