import Alamofire

extension URLRequestConvertible {

    var description: String {
        "\(urlRequest?.httpMethod ?? "") \(urlRequest?.url?.absoluteString ?? "")"
    }

}
