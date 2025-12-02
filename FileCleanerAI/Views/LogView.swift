import SwiftUI

struct LogView: View {
    @ObservedObject var logManager: LogManager
    @Binding var isShowing: Bool
    @State private var selectedLevels: Set<LogEntry.LogLevel> = [.info, .success, .warning, .error]
    @State private var selectedCategories: Set<LogEntry.LogCategory> = [.scanning, .ai, .deletion, .system, .general]
    @State private var searchText = ""
    @State private var showingExportSheet = false
    
    var filteredLogs: [LogEntry] {
        logManager.logs.filter { entry in
            let levelMatch = selectedLevels.contains(entry.level)
            let categoryMatch = selectedCategories.contains(entry.category)
            let searchMatch = searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText)
            return levelMatch && categoryMatch && searchMatch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.secondary)
                
                Text("Activity Logs")
                    .font(.headline)
                
                Spacer()
                
                // Log count badge
                Text("\(logManager.logs.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                
                Button(action: { withAnimation { isShowing = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Close logs")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Filters
            VStack(spacing: 8) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search logs...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                // Level filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([LogEntry.LogLevel.info, .success, .warning, .error, .debug], id: \.self) { level in
                            FilterChip(
                                title: level.rawValue,
                                icon: level.icon,
                                color: level.color,
                                isSelected: selectedLevels.contains(level)
                            ) {
                                toggleLevel(level)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Log entries
            if filteredLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No logs to display")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "Logs will appear here as you use the app" : "No logs match your search")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredLogs) { entry in
                                LogEntryRow(entry: entry)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                Divider()
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer actions
            HStack {
                Text("\(filteredLogs.count) of \(logManager.logs.count) logs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: exportLogs) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Button(action: clearLogs) {
                    Label("Clear All", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func toggleLevel(_ level: LogEntry.LogLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }
    
    private func clearLogs() {
        logManager.clearLogs()
    }
    
    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "filecleaner-logs-\(Date().formatted(.iso8601)).txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let content = logManager.exportLogs()
                try? content.write(to: url, atomically: true, encoding: .utf8)
                logManager.log("Logs exported to \(url.path)", level: .success, category: .system)
            }
        }
    }
}

// MARK: - Log Entry Row
struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Icon
            Image(systemName: entry.level.icon)
                .foregroundStyle(entry.level.color)
                .font(.system(size: 12))
                .frame(width: 16)
            
            // Timestamp
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .leading)
            
            // Category badge
            Text(entry.category.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(entry.level.color.opacity(0.2))
                .foregroundStyle(entry.level.color)
                .cornerRadius(4)
            
            // Message
            Text(entry.message)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundStyle(isSelected ? color : .secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LogView(logManager: LogManager.shared, isShowing: .constant(true))
        .frame(height: 600)
}

