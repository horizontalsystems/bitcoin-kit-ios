import HSHDWalletKit

public enum Bip {
    case bip44
    case bip49
    case bip84

    var scriptType: ScriptType {
        switch self {
        case .bip44: return .p2pkh
        case .bip49: return .p2wpkhSh
        case .bip84: return .p2wpkh
        }
    }

    var purpose: Purpose {
        switch self {
        case .bip44: return Purpose.bip44
        case .bip49: return Purpose.bip49
        case .bip84: return Purpose.bip84
        }
    }

}
