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

    private func formattedURL(_ url: String) -> String {
        "\(String(url.prefix(100)))..."
    }

    func add(error: Error) {
        if let error = error as? ApiError {
            let currentTime = formatter.string(from: Date())
            let value: String

            switch error {
            case .invalidRequest(let url): value = "\(formattedURL(url)) (InvalidRequest)"
            case .mappingError(let url): value = "\(formattedURL(url)) (MappingError)"
            case .noConnection(let url): value = "\(formattedURL(url)) (NoConnection)"
            case .serverError(let url, let status, _): value = "\(formattedURL(url)) (ServerError status: \(status))"
            }

            apiErrors.append((currentTime, value))
        }
    }

}
