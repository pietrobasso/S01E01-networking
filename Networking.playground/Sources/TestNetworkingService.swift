import Foundation

public extension Networking {
    
    public struct ResourceAndResponse {
        public let resource: Resource<Any>
        public let response: Result<Any, Error>?
        public init<A>(_ resource: Resource<A>, response: Result<A, Error>) {
            self.resource = resource.map { $0 }
            self.response = response.map { $0 }
        }
    }
    
}

public extension Networking {
    
    /// Networking testable service inspired by Swift Talk Episode 137: [Testing Networking Code](https://talk.objc.io/episodes/S01E137-testing-networking-code) by objc.io.
    public final class TestService: NetworkingService {
        
        public let configuration: Configuration
        public let urlSession = URLSession.shared
        public let behavior: CombinedRequestBehavior
        private var responses: [ResourceAndResponse]
        
        public init(configuration: Configuration, behavior: CombinedRequestBehavior = CombinedRequestBehavior(), responses: [ResourceAndResponse]) {
            self.configuration = configuration
            self.behavior = behavior
            self.responses = responses
        }
        
        public func task<A>(for resource: Resource<A>, completion: @escaping (Result<A, Error>) -> ()) throws -> URLSessionTask {
            let urlRequest = try resource.request.urlRequest(in: self)
            let behavior = self.behavior.appending(contentsOf: resource.request.behavior)
            behavior.beforeSend()
            let afterSend: (Result<A, Error>) -> () = { (result) in
                behavior.appending(contentsOf: resource.request.behavior).after(result: result)
                completion(result)
            }
            guard let index = try responses.firstIndex(where: { try $0.resource.request.urlRequest(in: self) == urlRequest }),
                let response = responses[index].response?.flatMap ({ (response) -> Result<A, Error> in
                    guard let response = response as? A else {
                        fatalError("No such resource: \(resource.request.endpoint)")
                    }
                    return Result(value: response)
                }) else {
                    fatalError("No such resource: \(resource.request.endpoint)")
            }
            responses.remove(at: index)
            afterSend(response)
            return URLSessionDataTask()
        }
        
        public func verify() {
            assert(responses.isEmpty)
        }
    }
    
}

