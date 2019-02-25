import Foundation

/// Represents a side-effect which can be performed during a network request.
///
/// Request behaviors are a useful way of separating the code that sends network requests from any side-effects that need to happen during that request.
/// This little abstraction simplifies network code, adds reusability for per-request behaviors, and vastly increases testability.
///
/// The basic idea is each behavior gets callbacks when specific network events occur, and they can execute code.
///
/// # Example
///
/// With this simple separation of request and side-effect, it’s now possible to test the client separately from each behavior we might want to add to it.
/// These behaviors themselves, since they’re their own objects, can be easily instantiated and tested.
///
///     struct AuthTokenHeaderBehavior: RequestBehavior {
///
///         let userDefaults = UserDefaults.standard
///
///         var additionalHeaders: [String : String] {
///             if let token = userDefaults.string(forKey: "authToken") {
///                 return ["X-Auth-Token": token]
///             }
///             return [:]
///         }
///
///     }
///
/// - Authors
///     - [Request Behaviors](http://khanlou.com/2017/01/request-behaviors/) by Soroush Khanlou
///     - [Soroush Khanlou - From Problem to Solution](https://www.youtube.com/watch?v=3G_ffcgRLMw&feature=youtu.be) at dotSwift 2019
public protocol RequestBehavior {
    
    typealias Result = Networking.Result
    typealias Error = Networking.Error
    
    var additionalHeaders: [String : String] { get }
    
    var additionalParameters: [String : Any?] { get }
    
    func addHeaders(to request: inout URLRequest)
    
    func addParameters(to url: inout URL)
    
    func beforeSend()
    
    func after<A>(result: Result<A, Error>)
    
}

public extension RequestBehavior {
    
    var additionalHeaders: [String : String] { return [:] }
    
    var additionalParameters: [String : Any?] { return [:] }
    
    func addHeaders(to request: inout URLRequest) {
        additionalHeaders.forEach({ request.addValue($1, forHTTPHeaderField: $0) })
    }
    
    func addParameters(to url: inout URL) {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let currentItems = urlComponents?.queryItems
        let items: [URLQueryItem] = additionalParameters
            .compactMap { (key, value) -> URLQueryItem? in
                guard let value = value else { return nil }
                return URLQueryItem(name: key, value: String(describing: value))
        }
        guard !items.isEmpty else { return }
        urlComponents?.queryItems = [items, currentItems]
            .compactMap { $0 }
            .flatMap { $0 }
        url = urlComponents?.url ?? url
    }
    
    func beforeSend() { }
    
    func after<A>(result: Result<A, Error>) { }
    
}

/// Composes multiple request behaviors / side-effects together.
///
/// Stores an array of behaviors and calls the relevant method on each behavior.
///
/// - Authors
///     - [Request Behaviors](http://khanlou.com/2017/01/request-behaviors/) by Soroush Khanlou
///     - [Soroush Khanlou - From Problem to Solution](https://www.youtube.com/watch?v=3G_ffcgRLMw&feature=youtu.be) at dotSwift 2019
public struct CombinedRequestBehavior: RequestBehavior {
    public typealias Result = Networking.Result
    public typealias Error = Networking.Error
    
    public let behaviors: [RequestBehavior]
    
    public init(_ behaviors: [RequestBehavior] = []) {
        self.behaviors = behaviors
    }
    
    public var additionalHeaders: [String : String] {
        return behaviors.reduce([String : String](), { (headers, behavior) in
            return headers.merging(behavior.additionalHeaders, uniquingKeysWith: { $1 })
        })
    }
    
    public var additionalParameters: [String : Any?] {
        return behaviors.reduce([String : Any?](), { (parameters, behavior) in
            return parameters.merging(behavior.additionalParameters, uniquingKeysWith: { $1 })
        })
    }
    
    public func addHeaders(to request: inout URLRequest) {
        behaviors.forEach({ $0.addHeaders(to: &request) })
    }
    
    public func addParameters(to url: inout URL) {
        behaviors.forEach({ $0.addParameters(to: &url) })
    }
    
    public func beforeSend() {
        behaviors.forEach({ $0.beforeSend() })
    }
    
    public func after<A>(result: Result<A, Error>) {
        behaviors.forEach({ $0.after(result: result) })
    }
    
    public func appending(contentsOf behavior: CombinedRequestBehavior) -> CombinedRequestBehavior {
        var copy = behaviors
        copy.append(contentsOf: behavior.behaviors)
        return CombinedRequestBehavior(copy)
    }
    
    public func appending(_ newElement: RequestBehavior) -> CombinedRequestBehavior {
        var copy = behaviors
        copy.append(newElement)
        return CombinedRequestBehavior(copy)
    }
    
}
