import Foundation

public struct Resource<A> {
    let request: Request
    let parse: (Data) -> Result<A, NetworkingError>
}

public extension Resource where A: Decodable {
    public init(request: Request,
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
                return Result(error: NetworkingError.codingError(.decodingFailed(error)))
            }
        }
    }
}
