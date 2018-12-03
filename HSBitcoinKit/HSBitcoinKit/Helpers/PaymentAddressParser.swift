import Foundation

class PaymentAddressParser: IPaymentAddressParser {
    fileprivate static let parameterVersion = "version"
    fileprivate static let parameterAmount = "amount"
    fileprivate static let parameterLabel = "label"
    fileprivate static let parameterMessage = "message"

    private let validScheme: String
    private let removeScheme: Bool

    init(validScheme: String, removeScheme: Bool) {
        self.validScheme = validScheme
        self.removeScheme = removeScheme
    }

    func parse(paymentAddress: String) -> BitcoinPaymentData {
        var parsedString = paymentAddress
        var address: String

        var version: String?
        var amount: Double?
        var label: String?
        var message: String?

        var parameters = [String: String]()

        let schemeSeparatedParts = paymentAddress.components(separatedBy: ":")
        // check exist scheme. If scheme equal network scheme (Bitcoin or bitcoincash), remove scheme for bitcoin or leave for cash. Otherwise, leave wrong scheme to make throw in validator
        if schemeSeparatedParts.count >= 2 {
            if schemeSeparatedParts[0] == validScheme {
                parsedString = removeScheme ? schemeSeparatedParts[1] : paymentAddress
            } else {
                parsedString = paymentAddress
            }
        }

        // check exist params
        var versionSeparatedParts = parsedString.components(separatedBy: CharacterSet(charactersIn: ";?"))
        guard versionSeparatedParts.count >= 2 else {
            address = parsedString

            return BitcoinPaymentData(address: address)
        }
        address = versionSeparatedParts.removeFirst()
        versionSeparatedParts.forEach { parameter in
            let parts = parameter.components(separatedBy: "=")
            if parts.count == 2 {
                switch parts[0] {
                case PaymentAddressParser.parameterVersion: version = parts[1]
                case PaymentAddressParser.parameterAmount: amount = Double(parts[1]) ?? nil
                case PaymentAddressParser.parameterLabel: label = parts[1]
                case PaymentAddressParser.parameterMessage: message = parts[1]
                default: parameters[parts[0]] = parts[1]
                }
            }
        }

        return BitcoinPaymentData(address: address, version: version, amount: amount, label: label, message: message, parameters: parameters.isEmpty ? nil : parameters)
    }

}
