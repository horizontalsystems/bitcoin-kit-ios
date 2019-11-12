class ErrorStorage {
    private let formatter: DateFormatter

    private var apiErrors = [(String, Any)]()
    var errors: Any {
        if apiErrors.count > 0 {
            return [("API errors", apiErrors)]
        } else {
            return "no errors"
        }
    }

    init() {
        formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MM/dd, HH:mm:ss")
    }

    private func formattedString(_ string: String) -> String {
        if string.count > 100 {
            return "\(String(string.prefix(100)))..."
        } else {
            return string
        }
    }

    func add(error: Error) {
        if let error = error as? ApiError {
            let currentTime = formatter.string(from: Date())
            let value: String

            switch error {
            case .invalidRequest(let url): value = "\(formattedString(url)) (InvalidRequest)"
            case .mappingError(let url): value = "\(formattedString(url)) (MappingError)"
            case .noConnection(let url): value = "\(formattedString(url)) (NoConnection)"
            case .serverError(let url, let status, let jsonData):
                var dataString = "n/a"
                if let jsonData = jsonData {
                    dataString = formattedString("\(jsonData)")
                }
                value = "\(formattedString(url)) (ServerError status: \(status); data: \(dataString)"
            }

            apiErrors.append((currentTime, value))
        }
    }

}
