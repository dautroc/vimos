import Foundation

public struct KeyMapping: Codable, Sendable {
    public let from: String
    public let to: String
    public let modes: [String]? // "normal", "insert", "visual". If nil, all.
    
    public init(from: String, to: String, modes: [String]? = nil) {
        self.from = from
        self.to = to
        self.modes = modes
    }
}

public struct VimOSConfig: Codable, Sendable {
    public let mappings: [KeyMapping]
    public let ignoredApplications: [String]
    
    public static let defaults = VimOSConfig(mappings: [], ignoredApplications: [])

    public init(mappings: [KeyMapping], ignoredApplications: [String]) {
        self.mappings = mappings
        self.ignoredApplications = ignoredApplications
    }
}

public class ConfigManager: @unchecked Sendable {
    public static let shared = ConfigManager()
    public var config: VimOSConfig = .defaults
    
    // For testing
    public func setConfig(_ config: VimOSConfig) {
        self.config = config
    }
    
    private let configURL: URL
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Ensure directory exists
        let configDir = home.appendingPathComponent(".vimos")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        self.configURL = configDir.appendingPathComponent("config.json")
        loadConfig()
    }
    
    public func loadConfig() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            // Create default config file if not exists ?? 
            // Maybe not, just leave it empty.
            return
        }
        
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            self.config = try decoder.decode(VimOSConfig.self, from: data)
            print("Loaded config: \(self.config.mappings.count) mappings, \(self.config.ignoredApplications.count) ignored apps.")
        } catch {
            print("Error loading config: \(error)")
        }
    }
    
    // Helper to reload if needed
    public func reload() {
        loadConfig()
    }
}
