import Foundation

public enum Networking {}

/// Networking Service inspired from Swift Talk Episode 1: [Networking](https://talk.objc.io/episodes/S01E01-networking).
///
/// Example usage given a struct `Episode: Decodable`
///
///     let request = Networking.Request(method: .get,
///                                      endpoint: "episodes.json")
///     let resource = Networking.Resource<[Episode]>(request: request)
///     let task = try? networkingService.task(for: resource) { print($0) }
///     task?.resume()
///
/// ## Inspirations
///
/// 1. [Tiny Networking Library](https://talk.objc.io/episodes/S01E1-tiny-networking-library) by objc.io
/// 2. [How to write Networking Layer in Swift (2nd version)](http://danielemargutti.com/2017/09/10/how-to-write-networking-layer-in-swift-2nd-version/) by Daniele Margutti
/// 3. [Networking: POST Requests](https://github.com/objcio/S01E08-networking-post-requests/tree/master/Networking%20POST%20Requests.playground/Pages) by objc.io
/// 4. [Swift Tip: Networking with Codable](https://www.objc.io/blog/2018/02/06/networking-with-codable/) by objc.io
/// 5. [Adding Caching](https://talk.objc.io/episodes/S01E25-adding-caching) by objc.io
/// 6. [Prefetching for UITableView](https://andreygordeev.com/2017/02/20/uitableview-prefetching/) by Andrey Gordeev
///
/// ## Reactive Extension Inspirations
///
/// 1. [API Client in Swift](http://kean.github.io/post/api-client) by Alexander Grebenyuk
/// 2. [Wrapping a URLRequest in RxSwift](https://github.com/newfivefour/BlogPosts/blob/master/swift-ios-rxswift-urlrequest.md) by newfivefour
/// 3. [URLSession+Rx](https://github.com/ReactiveX/RxSwift/blob/master/RxCocoa/Foundation/URLSession%2BRx.swift) by Krunoslav Zaher
///
public protocol NetworkingService {
    typealias Result = Networking.Result
    typealias Error = Networking.Error
    typealias Resource = Networking.Resource
    
    /// Configuration used by the service.
    var configuration: Networking.Configuration { get }
    
    /// An object that coordinates a group of related network data transfer tasks.
    var urlSession: URLSession { get }
    
    /// Headers used by the service.
    ///
    /// These headers are mirrored automatically to any Request made using the service.
    var headers: [String: String] { get set }
    
    /// Creates a `URLSessionTask` for a given resource.
    ///
    /// - Parameters:
    ///     - resource: Resource to request.
    ///     - completion: Response result.
    /// - Returns: `URLSessionTask`
    func task<A>(for resource: Resource<A>, completion: @escaping (Result<A, Error>) -> ()) throws -> URLSessionTask
}

public protocol NetworkingRequest {
    typealias Error = Networking.Error
    
    /// Endpoint of the request (ie. `auth/login`).
    var endpoint: String { get }
    
    /// HTTP method used to perform the request.
    var method: Networking.HttpMethod? { get }
    
    /// The data sent as the message body of a request, such as for an HTTP POST request.
    var body: Networking.RequestBody? { get }
    
    /// Parameters used to compose the query dictionary into the url.
    /// They will be automatically converted inside the url.
    /// `null` value wil be ignored automatically; all values must be also represented as `String`,
    /// otherwise will be ignored.
    /// For example `{ "p1" : "abc", "p2" : null, "p3" : 3 }` will be `.../endpoint?p1=abc&p3=3`
    var parameters: [String : Any?]? { get }
    
    /// Optional headers to append to the request.
    var headers: [String: String]? { get }
    
    /// Combines the specific request headers with the service's list
    /// and produce the headers to send along the request.
    /// You may not need to override this function; default implementation is already provided.
    /// Note: Default implementation prioritizie request's specific headers, so in case of duplicate
    /// header's key request's value win over the service's value.
    ///
    /// - Parameter service: service in which the request should be used.
    /// - Returns: `[String : String]`
    func headers(in service: NetworkingService) -> [String: String]
    
    /// Full url of the request when executed in a specific service.
    ///
    /// - Parameter service: service
    /// - Returns: `URL`
    func url(in service: NetworkingService) throws -> URL
    
    /// Create an URLRequest from a Request into the current service.
    ///
    /// - Parameter request: request
    /// - Returns: URLRequest
    /// - Throws: throw an exception if something goes wrong while making data
    func urlRequest(in service: NetworkingService) throws -> URLRequest
}


// MARK: - Provide default implementation of the Request
public extension NetworkingRequest {
    public func headers(in service: NetworkingService) -> [String: String] {
        var params = service.headers // initial set is composed by service's current headers
        // append (and replace if needed) with request's headers
        headers?.forEach({ k,v in params[k] = v })
        if let contentType = body?.contentType {
            params["Content-Type"] = contentType
        }
        return params
    }
    
    public func url(in service: NetworkingService) throws -> URL {
        let endpoint = [service.configuration.basePath, self.endpoint].joined(separator: "/")
        guard let url = URL(string: endpoint) else {
            throw Error.requestError(.invalidURL(endpoint))
        }
        return url
    }
    
    public func urlRequest(in service: NetworkingService) throws -> URLRequest {
        var urlRequest = URLRequest(url: try url(in: service))
        urlRequest.httpMethod = (method ?? .get).rawValue
        urlRequest.allHTTPHeaderFields = headers(in: service)
        if let bodyData = try body?.encodedData() {
            urlRequest.httpBody = bodyData
        }
        return urlRequest
    }
}

public extension Networking {
    public final class Service: NetworkingService {
        public let configuration: Configuration
        public let urlSession: URLSession
        public var headers: [String : String] = [:]
        
        /// Initialize a new service with the specified configuration.
        ///
        /// - Parameter configuration: configuration to use
        public init(_ configuration: Networking.Configuration) {
            self.configuration = configuration
            urlSession = URLSession(configuration: configuration.configuration)
        }
        
        public func task<A>(for resource: Resource<A>, completion: @escaping (Result<A, Error>) -> ()) throws -> URLSessionTask {
            return try urlSession.dataTask(with: resource.request.urlRequest(in: self)) { (data, response, error) in
                switch (data, response, error) {
                case (_, _, let error?):
                    if let response = response as? HTTPURLResponse {
                        completion(Result(error: .requestError(.apiError(response.statusCode))))
                    } else {
                        completion(Result(error: .requestError(.error(error))))
                    }
                case (let data?, let response?, _):
                    guard let response = response as? HTTPURLResponse else {
                        completion(Result(error: .requestError(.noHTTPResponse)))
                        return
                    }
                    if case (200..<300) = response.statusCode {
                        completion(resource.parse(data))
                    } else {
                        completion(Result(error: .requestError(.apiError(response.statusCode))))
                    }
                default:
                    fatalError("Invalid response combination \(data.debugDescription), \(response.debugDescription), \(error.debugDescription)")
                }
            }
        }
    }
}

public extension Networking {
    public class Request: NetworkingRequest {
        public let endpoint: String
        public let method: HttpMethod?
        public let body: RequestBody?
        public let parameters: [String: Any?]?
        public var headers: [String: String]? {
            didSet {
                guard let contentType = body?.contentType else { return }
                headers?["Content-Type"] = contentType
            }
        }
        
        /// Initialize a new request.
        ///
        /// - Parameters:
        ///   - method: HTTP Method request (if not specified, `.get` is used).
        ///   - body: Body of the request.
        ///   - endpoint: Endpoint of the request.
        ///   - parameters: Parameters used to compose the query dictionary into the url.
        ///   - headers: Headers appended to the request.
        public init(method: HttpMethod = .get, body: RequestBody? = nil, endpoint: String, parameters: [String: Any?]? = nil, headers: [String: String]? = nil) {
            self.method = method
            self.body = body
            self.endpoint = endpoint
            self.parameters = parameters
            self.headers = headers
        }
    }
}

public extension Networking {
    /// Class used to configure network connection with a backend server.
    public final class Configuration: CustomStringConvertible, Equatable {
        
        /// Base host url (ie. "http://www.myserver.com/api/v2").
        public let basePath: String
        
        /// A configuration object that defines behavior and policies for a URL session.
        public var configuration: URLSessionConfiguration = {
            let configuration = URLSessionConfiguration.default
            if #available(iOS 11.0, *) {
                configuration.waitsForConnectivity = true
            }
            return configuration
        }()
        
        /// Additional Dispatch Queue for async operations.
        public var dispatchQueue = DispatchQueue(label: "com.lisca.networking", qos: .utility, attributes: .concurrent)
        
        /// Initialize a new service configuration.
        ///
        /// - Parameters:
        ///   - base: base url of the service
        ///   - api: path to APIs service endpoint
        public init?(base: String, api: String?) {
            guard URL(string: base) != nil else { return nil }
            self.basePath = [base, api]
                .compactMap { $0 }
                .joined(separator: "/")
        }
        
        /// Attempt to load server configuration from `Info.plist`.
        ///
        /// - Returns: NetworkingConfiguration if `Info.plist` of the app can be parsed, `nil` otherwise.
        public static func appConfig() -> Configuration? {
            return Configuration()
        }
        
        /// Initialize a new service configuration by looking at `Info.plist` parameters.
        private convenience init?() {
            // Attempt to load the configuration inside the Info.plist of your app.
            // It must be a dictionary of `InfoPlist` type.
            guard let plist = Bundle.main.infoDictionary else { return nil }
            
            // Initialize with parameters
            self.init(base: plist["baseUrl"] as? String ?? "",
                      api: plist["api"] as? String)
            
            // Attempt to read a fixed list of headers from configuration
            configuration.httpAdditionalHeaders = plist["httpHeaders"] as? [String: String]
        }
        
        /// Readable description.
        public var description: String {
            return "\(self.basePath)"
        }
        
        /// A Service configuration is equal to another if both url and path to APIs endpoint are the same.
        ///
        /// - Parameters:
        ///   - lhs: configuration a
        ///   - rhs: configuration b
        /// - Returns: `true` if equals, `false` otherwise
        public static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
            return lhs.basePath.lowercased() == rhs.basePath.lowercased()
        }
    }
}

public extension Networking {
    public enum HttpMethod {
        case get
        case post
        case put
        case patch
        case delete
    }
}

public extension Networking.HttpMethod {
    public var rawValue: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .put: return "PUT"
        case .patch: return "PATCH"
        case .delete: return "DELETE"
        }
    }
}

public extension Networking {
    /// The data sent as the message body of a request, such as for an HTTP POST request.
    public enum RequestBody {
        typealias Error = Networking.Error
        
        case raw(Data)
        case json([String: Any?])
        case urlEncoded([String: Any?])
    }
}

public extension Networking.RequestBody {
    public var contentType: String? {
        switch self {
        case .json:
            return "application/json"
        case .urlEncoded:
            return "application/x-www-form-urlencoded"
        default:
            return nil
        }
    }
    
    /// Encoded data to carry out with the request.
    ///
    /// - Returns: `Data`
    public func encodedData() throws -> Data {
        switch self {
        case let .raw(data):
            return data
        case let .json(dictionary):
            return try JSONSerialization.data(withJSONObject: dictionary)
        case let .urlEncoded(dictionary):
            let encodedString = try Networking.RequestBody.urlEncodedString(forDictionary: dictionary)
            guard let data = encodedString.data(using: .utf8) else {
                throw Error.codingError(.dataIsNotEncodable(encodedString))
            }
            return data
        }
    }
    
    private static func urlEncodedString(forDictionary dictionary: [String: Any?], base: String = "") throws -> String {
        guard dictionary.count > 0 else { return base }
        let items: [URLQueryItem]? = dictionary.compactMap { (key, value) -> URLQueryItem? in
            guard let value = value else { return nil }
            return URLQueryItem(name: key, value: String(describing: value))
            }
            .reduce(into: nil) { return $0?.append($1) }
        var urlComponents = URLComponents(string: base)
        urlComponents?.queryItems = items
        guard let encodedString = urlComponents?.url else {
            throw Error.codingError(.dataIsNotEncodable(self))
        }
        return encodedString.absoluteString
    }
}

public extension Networking {
    public struct Resource<A> {
        let request: NetworkingRequest
        let parse: (Data) -> Result<A, Error>
    }
}

public extension Networking.Resource {
    typealias Resource = Networking.Resource
    
    public func map<B>(_ transform: @escaping (A) -> B) -> Resource<B> {
        return Resource<B>(request: request) { self.parse($0).map(transform) }
    }
}

public extension Networking.Resource where A: Decodable {
    typealias Result = Networking.Result
    typealias Error = Networking.Error
    
    public init(request: NetworkingRequest,
                keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase,
                dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601) {
        self.request = request
        self.parse = { data in
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = keyDecodingStrategy
            decoder.dateDecodingStrategy = dateDecodingStrategy
            do {
                return Result(value: try decoder.decode(A.self, from: data))
            } catch {
                return Result(error: Error.codingError(.decodingFailed(error)))
            }
        }
    }
}

public extension Networking.Resource where A == Void {
    public init(request: NetworkingRequest) {
        self.request = request
        self.parse = { _ in Result(value: ())}
    }
}

public extension Networking {
    public enum Result<T, Error> {
        case success(T)
        case failure(Error)
        
        public init(value: T) {
            self = .success(value)
        }
        
        public init(error: Error) {
            self = .failure(error)
        }
        
        public func map<U>(_ transform: (T) -> U) -> Result<U, Error> {
            switch self {
            case .success(let x): return .success(transform(x))
            case .failure(let e): return .failure(e)
            }
        }
        
        public func flatMap<U>(_ transform: (T) -> Result<U, Error>) -> Result<U, Error> {
            switch self {
            case let .success(success):
                return transform(success)
            case let .failure(failure):
                return .failure(failure)
            }
        }
    }
}

public extension Networking {
    public enum Error: Swift.Error {
        case codingError(CodingError)
        case requestError(RequestError)
    }
    
    public enum RequestError {
        public typealias StatusCode = Int
        
        case error(Swift.Error)
        case apiError(StatusCode)
        case noHTTPResponse
        case invalidURL(String)
    }
    
    public enum CodingError {
        case encodingFailed(Swift.Error?)
        case decodingFailed(Swift.Error?)
        case dataIsNotEncodable(Any)
    }
}
