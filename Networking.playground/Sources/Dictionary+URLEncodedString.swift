import Foundation

public extension Dictionary where Key == String, Value == Any? {
    /// Encode a dictionary as url encoded string
    ///
    /// - Parameter base: base url
    /// - Returns: encoded string
    /// - Throws: throw `.dataIsNotEncodable` if data cannot be encoded
    public func urlEncodedString(base: String = "") throws -> String {
        guard count > 0 else { return base }
        let items: [URLQueryItem]? = compactMap { (key, value) -> URLQueryItem? in
            guard let value = value else { return nil }
            return URLQueryItem(name: key, value: String(describing: value))
            }
            .reduce(nil) { return $0?.appending($1) }
        var urlComponents = URLComponents(string: base)
        urlComponents?.queryItems = items
        guard let encodedString = urlComponents?.url else {
            throw NetworkingError.codingError(.dataIsNotEncodable(self))
        }
        return encodedString.absoluteString
    }
}
