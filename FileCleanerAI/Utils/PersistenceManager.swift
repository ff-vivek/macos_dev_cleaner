import Foundation

@MainActor
class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let fileManager = FileManager.default
    private let scanDataURL: URL
    
    private init() {
        // Create app support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("FileCleanerAI", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        scanDataURL = appDirectory.appendingPathComponent("scan_data.json")
    }
    
    // MARK: - Save/Load Scan Data
    
    func saveScanData(files: [DiscoveredFile], patterns: [FilePattern]) {
        let scanData = ScanDataStorage(
            files: files,
            patterns: patterns,
            scanDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(scanData)
            try data.write(to: scanDataURL)
            
            LogManager.shared.log("Scan data saved successfully", level: .success, category: .system)
        } catch {
            LogManager.shared.log("Failed to save scan data: \(error.localizedDescription)", level: .error, category: .system)
        }
    }
    
    func loadScanData() -> ScanDataStorage? {
        guard fileManager.fileExists(atPath: scanDataURL.path) else {
            LogManager.shared.log("No saved scan data found", level: .info, category: .system)
            return nil
        }
        
        do {
            let data = try Data(contentsOf: scanDataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let scanData = try decoder.decode(ScanDataStorage.self, from: data)
            
            LogManager.shared.log("Loaded scan data from \(scanData.scanDate.formatted())", level: .success, category: .system)
            return scanData
        } catch {
            LogManager.shared.log("Failed to load scan data: \(error.localizedDescription)", level: .error, category: .system)
            return nil
        }
    }
    
    func clearScanData() {
        try? fileManager.removeItem(at: scanDataURL)
        LogManager.shared.log("Scan data cleared", level: .info, category: .system)
    }
    
    func getScanDataAge() -> String? {
        guard let scanData = loadScanData() else { return nil }
        
        let timeInterval = Date().timeIntervalSince(scanData.scanDate)
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Storage Models

struct ScanDataStorage: Codable {
    let files: [DiscoveredFile]
    let patterns: [FilePattern]
    let scanDate: Date
}

// Make DiscoveredFile Codable
extension DiscoveredFile: Codable {
    enum CodingKeys: String, CodingKey {
        case path, size, name, isDirectory, modificationDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        size = try container.decode(Int.self, forKey: .size)
        name = try container.decode(String.self, forKey: .name)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(size, forKey: .size)
        try container.encode(name, forKey: .name)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encodeIfPresent(modificationDate, forKey: .modificationDate)
    }
}

