import Foundation

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
}
