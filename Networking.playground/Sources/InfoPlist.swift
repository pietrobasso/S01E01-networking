import Foundation

public struct InfoPlist: Codable {
    let configuration: Configuration
    
    struct Configuration: Codable {
        let baseUrl: String
        let api: String
        let headers: [String: String]
    }
}
