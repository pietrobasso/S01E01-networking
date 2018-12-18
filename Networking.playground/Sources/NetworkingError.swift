public enum NetworkingError: Error {
    case codingError(CodingError)
    case requestError(RequestError)
}

public typealias StatusCode = Int

public enum RequestError {
    case error(Error)
    case apiError(StatusCode)
    case noHTTPResponse
    case invalidURL(String)
}

public enum CodingError {
    case encodingFailed(Error?)
    case decodingFailed(Error?)
    case dataIsNotEncodable(Any)
}
