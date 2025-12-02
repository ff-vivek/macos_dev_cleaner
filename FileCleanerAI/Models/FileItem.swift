import Foundation

// MARK: - File Pattern
struct FilePattern: Identifiable, Codable {
    let id: String
    let patternName: String
    let paths: [String]
    let safetyScore: SafetyScore
    let reason: String
    let count: Int
    let totalSize: Int
    
    init(patternName: String, paths: [String], safetyScore: SafetyScore, reason: String, count: Int, totalSize: Int) {
        self.id = UUID().uuidString
        self.patternName = patternName
        self.paths = paths
        self.safetyScore = safetyScore
        self.reason = reason
        self.count = count
        self.totalSize = totalSize
    }
}

// MARK: - Safety Score
enum SafetyScore: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

// MARK: - Discovered File
struct DiscoveredFile {
    let path: String
    let size: Int
    let name: String
    let isDirectory: Bool
    let modificationDate: Date?
    
    var displayPath: String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}

// MARK: - Chat Message
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Scan Configuration
struct ScanConfiguration {
    static let defaultDirectories = [
        "~/Documents",
        "~/Downloads",
        "~/Desktop",
        "~/Library/Caches",
        "~/Library/Logs"
    ]
    
    static let commonTempPatterns = [
        "node_modules",
        "build",
        ".gradle",
        "target",
        "dist",
        ".next",
        ".nuxt",
        "vendor",
        "__pycache__",
        ".pytest_cache",
        "Pods",
        "DerivedData",
        ".DS_Store"
    ]
    
    static let fileExtensions = [
        ".log",
        ".tmp",
        ".cache",
        ".zip",
        ".tar",
        ".gz"
    ]
}

