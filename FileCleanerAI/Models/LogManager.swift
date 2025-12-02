import Foundation
import SwiftUI

// MARK: - Log Entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let category: LogCategory
    
    enum LogLevel: String {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARNING"
        case error = "ERROR"
        case debug = "DEBUG"
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .debug: return .secondary
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .debug: return "ant.circle.fill"
            }
        }
    }
    
    enum LogCategory: String {
        case scanning = "Scanning"
        case ai = "AI Analysis"
        case deletion = "Deletion"
        case system = "System"
        case general = "General"
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Log Manager
@MainActor
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    @Published var maxLogs: Int = 500
    
    private init() {
        log("Log system initialized", level: .info, category: .system)
    }
    
    func log(_ message: String, level: LogEntry.LogLevel = .info, category: LogEntry.LogCategory = .general) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category
        )
        
        logs.insert(entry, at: 0)
        
        // Keep only the most recent logs
        if logs.count > maxLogs {
            logs = Array(logs.prefix(maxLogs))
        }
        
        // Also print to console for debugging
        print("[\(level.rawValue)] [\(category.rawValue)] \(message)")
    }
    
    func clearLogs() {
        logs.removeAll()
        log("Logs cleared", level: .info, category: .system)
    }
    
    func exportLogs() -> String {
        logs.reversed().map { entry in
            "[\(entry.formattedTimestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

