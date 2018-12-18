import Foundation

public enum RequestMethod {
    case get(RequestBody?)
    case post(RequestBody?)
    case put(RequestBody)
    case patch(RequestBody)
    case delete
}

public extension RequestMethod {
    var rawValue: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .put: return "PUT"
        case .patch: return "PATCH"
        case .delete: return "DELETE"
        }
    }
    
    var body: RequestBody? {
        switch self {
        case .get(let body): return body
        case .post(let body): return body
        case .put(let body): return body
        case .patch(let body): return body
        case .delete: return nil
        }
    }
}


/// The data sent as the message body of a request, such as for an HTTP POST request.
public enum RequestBody {
    case raw(Data)
    case json([String: Any?])
    case urlEncoded([String: Any?])
}

public extension RequestBody {
    var contentType: String? {
        switch self {
        case .json:
            return "application/json"
        case .urlEncoded:
            return "application/x-www-form-urlencoded"
        default:
            return nil
        }
    }
    
    /// Encoded data to carry out with the request
    ///
    /// - Returns: Data
    func encodedData() throws -> Data {
        switch self {
        case let .raw(data):
            return data
        case let .json(dictionary):
            return try JSONSerialization.data(withJSONObject: dictionary)
        case let .urlEncoded(dictionary):
            let encodedString = try dictionary.urlEncodedString()
            guard let data = encodedString.data(using: .utf8) else {
                throw NetworkingError.codingError(.dataIsNotEncodable(encodedString))
            }
            return data
        }
    }
}

/// This is the base class for a Request
public protocol Request {
    
    /// This is the endpoint of the request (ie. `auth/login`)
    var endpoint: Path<Relative, Directory> { get }
    
    /// The HTTP method used to perform the request.
    var method: RequestMethod? { get }
    
    /// Parameters used to compose the query dictionary into the url.
    /// They will be automatically converted inside the url.
    /// `null` value wil be ignored automatically; all values must be also represented as `String`,
    /// otherwise will be ignored.
    /// For example `{ "p1" : "abc", "p2" : null, "p3" : 3 }` will be `.../endpoint?p1=abc&p3=3`
    var parameters: [String : Any?]? { get }
    
    /// Optional headers to append to the request.
    var headers: [String: String]? { get }
    
    /// This function combine the specific request headers with the service's list
    /// and produce the headers to send along the request.
    /// You may not need to override this function; default implementation is already provided.
    /// Note: Default implementation prioritizie request's specific headers, so in case of duplicate
    /// header's key request's value win over the service's value.
    ///
    /// - Parameter service: service in which the request should be used
    /// - Returns: [String : String]
    func headers(in service: Webservice) -> [String: String]
    
    /// Return the full url of the request when executed in a specific service
    ///
    /// - Parameter service: service
    /// - Returns: URL
    func url(in service: Webservice) throws -> URL
    
    /// Create an URLRequest from a Request into the current service.
    ///
    /// - Parameter request: request
    /// - Returns: URLRequest
    /// - Throws: throw an exception if something goes wrong while making data
    func urlRequest(in service: Webservice) throws -> URLRequest
}


// MARK: - Provide default implementation of the Request
public extension Request {
    func headers(in service: Webservice) -> [String: String] {
        var params = service.headers // initial set is composed by service's current headers
        // append (and replace if needed) with request's headers
        headers?.forEach({ k,v in params[k] = v })
        if let contentType = method?.body?.contentType {
            params["Content-Type"] = contentType
        }
        return params
    }
    
    func url(in service: Webservice) throws -> URL {
        let endpoint = service.configuration.basePath.appendingPath(directory: self.endpoint).rendered
        guard let url = URL(string: endpoint) else {
            throw NetworkingError.requestError(.invalidURL(endpoint))
        }
        return url
    }
    
    func urlRequest(in service: Webservice) throws -> URLRequest {
        var urlRequest = URLRequest(url: try url(in: service))
        urlRequest.httpMethod = (method ?? .get(nil)).rawValue
        urlRequest.allHTTPHeaderFields = headers(in: service)
        if let bodyData = try method?.body?.encodedData() {
            urlRequest.httpBody = bodyData
        }
        return urlRequest
    }
}

public class RequestImplementation: Request {
    public let endpoint: Path<Relative, Directory>
    public let method: RequestMethod?
    public let parameters: [String: Any?]?
    public var headers: [String: String]? {
        didSet {
            guard let contentType = method?.body?.contentType else { return }
            headers?["Content-Type"] = contentType
        }
    }
    
    /// Initialize a new request
    ///
    /// - Parameters:
    ///   - method: HTTP Method request (if not specified, `.get` is used)
    ///   - endpoint: Endpoint of the request
    ///   - parameters: Parameters used to compose the query dictionary into the url.
    ///   - headers: Headers appended to the request.
    public init(method: RequestMethod = .get(nil), endpoint: Path<Relative, Directory>, parameters: [String: Any?]?, headers: [String: String]?) {
        self.method = method
        self.endpoint = endpoint
        self.parameters = parameters
        self.headers = headers
    }
}
