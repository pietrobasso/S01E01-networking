import Foundation

public enum Networking {}

/// Networking Service inspired by Swift Talk Episode 1: [Networking](https://talk.objc.io/episodes/S01E01-networking).
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
    
    typealias Configuration = Networking.Configuration
    typealias Resource = Networking.Resource
    typealias Result = Networking.Result
    typealias Error = Networking.Error
    
    /// Configuration used to configure network connection with a backend server.
    var configuration: Configuration { get }
    
    /// An object that coordinates a group of related network data transfer tasks.
    var urlSession: URLSession { get }
    
    /// Behavior used by the service.
    var behavior: CombinedRequestBehavior { get }
    
    /// Creates a `URLSessionTask` for a given resource.
    ///
    /// Combines the behavior for the individual resource and the behavior for the whole service.
    /// It builds the request using the `additionalHeaders` and `additionalParameters`,
    /// and then it calls `beforeSend` and `after(result:)` at the appropriate times and with the appropriate values.
    ///
    /// - Parameters:
    ///     - resource: Resource to request.
    ///     - completion: The completion handler to call when the load request is complete.
    /// - Returns: `URLSessionTask`
    func task<A>(for resource: Resource<A>, completion: @escaping (Result<A, Error>) -> ()) throws -> URLSessionTask
    
}

public protocol NetworkingRequest {
    
    typealias HttpMethod = Networking.HttpMethod
    typealias RequestBody = Networking.RequestBody
    typealias Error = Networking.Error
    
    /// HTTP method used to perform the request.
    var method: HttpMethod? { get }
    
    /// The data sent as the message body of a request, such as for an HTTP POST request.
    var body: RequestBody? { get }
    
    /// Endpoint of the request (ie. `auth/login`).
    var endpoint: String { get }
    
    /// Behavior used by the request.
    var behavior: CombinedRequestBehavior { get }
    /// Full url of the request when executed in a specific service.
    
    ///
    /// Combines the specific request behavior with the service's behavior to create the full url for the request.
    ///
    /// - Parameter service: Networking Service where the task will be executed.
    /// - Returns: `URL`
    /// - Throws:
    ///     throws an exception if the URL cannot be formed with the string
    ///     (for example, if the string contains characters that are illegal in a URL, or is an empty string).
    func url(in service: NetworkingService) throws -> URL
    
    /// Create a URLRequest from a Request into the current service.
    ///
    /// Combines the specific request behavior with the service's behavior.
    /// You may not need to override this function; default implementation is already provided.
    /// - Important:
    ///     Default implementation prioritizie the individual request behavior, so in case of duplicates
    ///     the individual request behavior wins over the service's behavior.
    ///
    /// - Parameter service: Networking Service where the task will be executed.
    /// - Returns: URLRequest
    /// - Throws: throws an exception if something goes wrong while encoding the request body.
    func urlRequest(in service: NetworkingService) throws -> URLRequest
    
}

public extension NetworkingRequest {
    
    public func url(in service: NetworkingService) throws -> URL {
        let endpoint = [service.configuration.basePath, self.endpoint].joined(separator: "/")
        guard var url = URL(string: endpoint) else {
            throw Error.requestError(.invalidURL(endpoint))
        }
        service.behavior.appending(contentsOf: behavior).addParameters(to: &url)
        return url
    }
    
    public func urlRequest(in service: NetworkingService) throws -> URLRequest {
        var urlRequest = URLRequest(url: try url(in: service))
        urlRequest.httpMethod = (method ?? .get).rawValue
        service.behavior.appending(contentsOf: behavior).addHeaders(to: &urlRequest)
        if let bodyData = try body?.encodedData() {
            urlRequest.httpBody = bodyData
        }
        if let contentType = body?.contentType {
            urlRequest.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        return urlRequest
    }
    
}

// MARK: - Extension: NetworkingService Implementation
public extension Networking {
    
    public final class Service: NetworkingService {
        
        public let configuration: Configuration
        
        public let urlSession: URLSession
        
        public let behavior: CombinedRequestBehavior
        
        /// Initialize a new service with the specified configuration.
        ///
        /// - Parameter configuration: configuration to use
        public init(_ configuration: Networking.Configuration, behaviors: CombinedRequestBehavior = CombinedRequestBehavior()) {
            self.configuration = configuration
            self.behavior = behaviors
            urlSession = URLSession(configuration: configuration.configuration)
        }
        
        public func task<A>(for resource: Resource<A>, completion: @escaping (Result<A, Error>) -> ()) throws -> URLSessionTask {
            let request = try resource.request.urlRequest(in: self)
            let behavior = self.behavior.appending(contentsOf: resource.request.behavior)
            behavior.beforeSend()
            let afterSend: (Result<A, Error>) -> () = { (result) in
                behavior.appending(contentsOf: resource.request.behavior).after(result: result)
                completion(result)
            }
            return urlSession.dataTask(with: request) { (data, response, error) in
                switch (data, response, error) {
                case (_, _, let error?):
                    if let response = response as? HTTPURLResponse {
                        afterSend(Result(error: .requestError(.apiError(response.statusCode))))
                    } else {
                        afterSend(Result(error: .requestError(.error(error))))
                    }
                case (let data?, let response?, _):
                    guard let response = response as? HTTPURLResponse else {
                        afterSend(Result(error: .requestError(.noHTTPResponse)))
                        return
                    }
                    if case (200..<300) = response.statusCode {
                        afterSend(resource.parse(data))
                    } else {
                        afterSend(Result(error: .requestError(.apiError(response.statusCode))))
                    }
                default:
                    fatalError("Invalid response combination \(data.debugDescription), \(response.debugDescription), \(error.debugDescription)")
                }
            }
        }
        
    }
    
}

// MARK: - Extension: NetworkingRequest Implementation
extension Networking {
    
    public class Request: NetworkingRequest {
        public let endpoint: String
        public let method: HttpMethod?
        public let body: RequestBody?
        public let behavior: CombinedRequestBehavior
        
        /// Initialize a new request.
        ///
        /// - Parameters:
        ///   - method: HTTP Method request (if not specified, `.get` is used).
        ///   - body: Body of the request.
        ///   - endpoint: Endpoint of the request.
        ///   - behavior: Behavior of the request.
        public init(method: HttpMethod = .get, body: RequestBody? = nil, endpoint: String, behavior: CombinedRequestBehavior = CombinedRequestBehavior()) {
            self.method = method
            self.body = body
            self.endpoint = endpoint
            self.behavior = behavior
        }
        
    }
    
}

// MARK: - Extension: Configuration
public extension Networking {
    
    /// Class used to configure network connection with a backend server.
    public final class Configuration: CustomStringConvertible, Equatable {
        
        /// Base host url (ie. "http://www.myserver.com/api/v2").
        public let basePath: String
        
        /// A configuration object that defines behavior and policies for a URL session.
        public let configuration: URLSessionConfiguration
        
        /// Additional Dispatch Queue for async operations.
        public let dispatchQueue: DispatchQueue
        
        /// Initialize a new service configuration.
        ///
        /// - Parameters:
        ///   - base: base url of the service
        ///   - api: path to APIs service endpoint
        public init?(base: String, api: String?, configuration: URLSessionConfiguration = .default) {
            guard URL(string: base) != nil else { return nil }
            self.basePath = [base, api]
                .compactMap { $0 }
                .joined(separator: "/")
            self.configuration = configuration
            self.dispatchQueue = DispatchQueue(label: basePath, qos: .utility, attributes: .concurrent)
        }
        
        /// Attempt to load server configuration from `Info.plist`.
        ///
        /// - Returns: NetworkingConfiguration if `Info.plist` of the app can be parsed, `nil` otherwise.
        public static func appConfig(configuration: URLSessionConfiguration = .default) -> Configuration? {
            return Configuration(configuration: configuration)
        }
        
        /// Initialize a new service configuration by looking at `Info.plist` parameters.
        private convenience init?(configuration: URLSessionConfiguration = .default) {
            // Attempt to load the configuration inside the Info.plist of your app.
            guard let plist = Bundle.main.infoDictionary else { return nil }
            
            // Initialize with parameters
            self.init(base: plist["baseUrl"] as? String ?? "",
                      api: plist["api"] as? String,
                      configuration: configuration)
            
            // Attempt to read a fixed list of headers from configuration
            configuration.httpAdditionalHeaders = plist["httpHeaders"] as? [String : String]
        }
        
        /// Readable description.
        public var description: String {
            return "\(self.basePath)"
        }
        
        /// A Service configuration is equal to another if both base paths are the same.
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

// MARK: - Extension: Request Method
public extension Networking {
    
    public enum HttpMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }
    
}

// MARK: - Extension: Request Body
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
        case let .urlEncoded(body):
            return try urlEncodedData(with: body)
        }
    }
    
    private func urlEncodedData(with body: [String: Any?]) throws -> Data {
        var urlComponents = URLComponents(string: "")
        let items: [URLQueryItem] = body
            .compactMap { (key, value) -> URLQueryItem? in
                guard let value = value else { return nil }
                return URLQueryItem(name: key, value: String(describing: value))
        }
        guard !items.isEmpty else { return Data() }
        urlComponents?.queryItems = items
        guard let data = urlComponents?.query?.data(using: .utf8) else {
            throw Error.codingError(.dataIsNotEncodable(self))
        }
        return data
    }
    
}

// MARK: - Extension: Resource
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

// MARK: - Extension: Result
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

// MARK: - Extension: Error
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
