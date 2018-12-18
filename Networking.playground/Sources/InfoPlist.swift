import Foundation

public struct InfoPlist: Codable {
    let configuration: Configuration
    
    struct Configuration: Codable {
        let google: Google
        let urls: Urls
        let firebase: Firebase
    }
    
    struct Urls: Codable {
        let server: String
    }
    
    struct Google: Codable {
        let clientId: String
    }
    
    struct Firebase: Codable {
        let storageUrl: String
        let googleInfoPlist: String
    }
}
