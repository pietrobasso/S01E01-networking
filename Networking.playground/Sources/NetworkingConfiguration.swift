import Foundation

/// This class is used to configure network connection with a backend server
public final class NetworkingConfiguration: CustomStringConvertible, Equatable {
    
    /// This is the base host url (ie. "http://www.myserver.com/api/v2")
    public let basePath: Path<Relative, Directory>
    
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
    
    /// Initialize a new service configuration
    ///
    /// - Parameters:
    ///   - base: base url of the service
    ///   - api: path to APIs service endpoint
    public init?(base: String, api: String?) {
        guard URL(string: base) != nil else { return nil }
        self.basePath = Path<Relative, Directory>(directoryComponents: [base, api].compactMap{ $0 })
    }
    
    /// Attempt to load server configuration from Info.plist
    ///
    /// - Returns: NetworkingConfiguration if Info.plist of the app can be parsed, `nil` otherwise
    public static func appConfig() -> NetworkingConfiguration? {
        return NetworkingConfiguration()
    }
    
    /// Initialize a new service configuration by looking at parameters
    private convenience init?() {
        // Attemp to load the configuration inside the Info.plist of your app.
        // It must be a dictionary of `InfoPlist` type.
        guard let plist = try? Plist<InfoPlist>() else { return nil }
        
        // Initialize with parameters
        self.init(base: plist.data.configuration.baseUrl,
                  api: plist.data.configuration.api)
        
        // Attempt to read a fixed list of headers from configuration
        configuration.httpAdditionalHeaders = plist.data.configuration.headers
    }
    
    /// Readable description
    public var description: String {
        return "\(self.basePath.rendered)"
    }
    
    /// A Service configuration is equal to another if both url and path to APIs endpoint are the same.
    /// This comparison ignore service name.
    ///
    /// - Parameters:
    ///   - lhs: configuration a
    ///   - rhs: configuration b
    /// - Returns: `true` if equals, `false` otherwise
    public static func ==(lhs: NetworkingConfiguration, rhs: NetworkingConfiguration) -> Bool {
        return lhs.basePath.rendered.lowercased() == rhs.basePath.rendered.lowercased()
    }
}
