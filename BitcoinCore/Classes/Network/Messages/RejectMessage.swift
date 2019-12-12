/// The reject message is sent when messages are rejected.
struct RejectMessage: IMessage {
    /// type of message rejected
    let message: VarString
    /// code relating to rejected message
    /// 0x01  REJECT_MALFORMED
    /// 0x10  REJECT_INVALID
    /// 0x11  REJECT_OBSOLETE
    /// 0x12  REJECT_DUPLICATE
    /// 0x40  REJECT_NONSTANDARD
    /// 0x41  REJECT_DUST
    /// 0x42  REJECT_INSUFFICIENTFEE
    /// 0x43  REJECT_CHECKPOINT
    let ccode: UInt8
    /// text version of reason for rejection
    let reason: VarString
    /// Optional extra data provided by some errors.
    /// Currently, all errors which provide this field fill it with the TXID or
    /// block header hash of the object being rejected, so the field is 32 bytes.
    let data: Data

    var description: String {
        return "\(message) code: 0x\(String(ccode, radix: 16)) reason: \(reason)"
    }

}
