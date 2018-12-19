import Foundation

public protocol NetworkingService {
    /// This is the configuration used by the service.
    var configuration: NetworkingConfiguration { get }
    
    /// An object that coordinates a group of related network data transfer tasks.
    var urlSession: URLSession { get }
    
    /// Headers used by the service.
    ///
    /// These headers are mirrored automatically to any Request made using the service.
    var headers: [String: String] { get set }
    
    /// Request a resource.
    ///
    /// - Parameters:
    ///     - resource: Resource to request.
    ///     - completion: Response result.
    func request<A>(resource: Resource<A>, completion: @escaping (Result<A, NetworkingError>) -> ()) throws -> URLSessionTask
}

public final class NetworkingServiceImplementation: NetworkingService {
    public let configuration: NetworkingConfiguration
    public let urlSession: URLSession
    public var headers: [String : String] = [:]
    
    /// Initialize a new service with specified configuration
    ///
    /// - Parameter configuration: configuration to use
    public init(_ configuration: NetworkingConfiguration) {
        self.configuration = configuration
        urlSession = URLSession(configuration: configuration.configuration)
    }
    
    public func request<A>(resource: Resource<A>, completion: @escaping (Result<A, NetworkingError>) -> ()) throws -> URLSessionTask {
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
