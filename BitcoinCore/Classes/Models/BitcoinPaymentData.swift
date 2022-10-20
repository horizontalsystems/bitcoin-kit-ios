import Foundation

public struct BitcoinPaymentData: Equatable {
    public let address: String

    public let version: String?
    public let amount: Double?
    public let label: String?
    public let message: String?

    public let parameters: [String: String]?

    init(address: String, version: String? = nil, amount: Double? = nil, label: String? = nil, message: String? = nil, parameters: [String: String]? = nil) {
        self.address = address
        self.version = version
        self.amount = amount
        self.label = label
        self.message = message
        self.parameters = parameters
    }

    var uriPaymentAddress: String {
        var uriAddress = address
        if let version = version {
            uriAddress.append(";version=" + version)
        }
        if let amount = amount {
            uriAddress.append("?amount=\(amount)")
        }
        if let label = label {
            uriAddress.append("?label=" + label)
        }
        if let message = message {
            uriAddress.append("?message=" + message)
        }
        if let parameters = parameters {
            for (name, value) in parameters {
                uriAddress.append("?\(name)=" + value)
            }
        }

        return uriAddress
    }

    public static func ==(lhs: BitcoinPaymentData, rhs: BitcoinPaymentData) -> Bool {
        return lhs.address == rhs.address &&
                lhs.version == rhs.version &&
                lhs.amount == rhs.amount &&
                lhs.label == rhs.label &&
                lhs.message == rhs.message &&
                lhs.parameters == rhs.parameters
    }

}
