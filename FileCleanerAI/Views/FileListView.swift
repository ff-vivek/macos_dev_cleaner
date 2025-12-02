import SwiftUI

struct FilePatternListView: View {
    let patterns: [FilePattern]
    @Binding var selectedPatterns: Set<String>
    let searchQuery: String
    @State private var detailViewPattern: FilePattern?
    @State private var showingDetailView = false
    @State private var sortOrder: SortOrder = .sizeDescending
    @State private var localSearchQuery = ""
    @State private var showFilesOnly = false
    @State private var showFoldersOnly = false
    
    enum SortOrder: String, CaseIterable {
        case sizeDescending = "Size (Largest)"
        case sizeAscending = "Size (Smallest)"
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case countDescending = "Count (Most)"
        case countAscending = "Count (Least)"
    }
    
    var filteredPatterns: [FilePattern] {
        var result = patterns
        
        // Apply search filter (use local search or external)
        let effectiveSearch = localSearchQuery.isEmpty ? searchQuery : localSearchQuery
        if !effectiveSearch.isEmpty {
            result = result.filter { pattern in
                pattern.patternName.localizedCaseInsensitiveContains(effectiveSearch) ||
                pattern.reason.localizedCaseInsensitiveContains(effectiveSearch)
            }
        }
        
        // Apply file type filters
        if showFilesOnly && !showFoldersOnly {
            result = result.filter { isPatternPrimarilyFiles($0) }
        } else if showFoldersOnly && !showFilesOnly {
            result = result.filter { isPatternPrimarilyFolders($0) }
        }
        
        // Apply sort order
        switch sortOrder {
        case .sizeDescending:
            result.sort { $0.totalSize > $1.totalSize }
        case .sizeAscending:
            result.sort { $0.totalSize < $1.totalSize }
        case .nameAscending:
            result.sort { $0.patternName.localizedCaseInsensitiveCompare($1.patternName) == .orderedAscending }
        case .nameDescending:
            result.sort { $0.patternName.localizedCaseInsensitiveCompare($1.patternName) == .orderedDescending }
        case .countDescending:
            result.sort { $0.count > $1.count }
        case .countAscending:
            result.sort { $0.count < $1.count }
        }
        
        return result
    }
    
    private func isPatternPrimarilyFiles(_ pattern: FilePattern) -> Bool {
        // Patterns with file extensions are primarily files
        if pattern.patternName.hasPrefix("*.") || pattern.patternName.contains("files") {
            return true
        }
        // Check known folder patterns
        let folderPatterns = ["node_modules", "build", "dist", "target", ".gradle", "Pods", "DerivedData", "vendor"]
        return !folderPatterns.contains(where: { pattern.patternName.contains($0) })
    }
    
    private func isPatternPrimarilyFolders(_ pattern: FilePattern) -> Bool {
        // Known folder patterns
        let folderPatterns = ["node_modules", "build", "dist", "target", ".gradle", "Pods", "DerivedData", "vendor", "__pycache__"]
        return folderPatterns.contains(where: { pattern.patternName.contains($0) })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary Stats
            StatsHeaderView(patterns: patterns)
            
            Divider()
            
            // Search Bar with Toggleable Filter Icons
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search patterns...", text: $localSearchQuery)
                    .textFieldStyle(.plain)
                
                if !localSearchQuery.isEmpty {
                    Button(action: { localSearchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                // Toggleable filter icons
                Button(action: {
                    showFilesOnly.toggle()
                    if showFilesOnly && showFoldersOnly {
                        showFoldersOnly = false
                    }
                }) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(showFilesOnly ? .blue : .secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help(showFilesOnly ? "Showing file patterns only (click to show all)" : "Show file patterns only")
                
                Button(action: {
                    showFoldersOnly.toggle()
                    if showFoldersOnly && showFilesOnly {
                        showFilesOnly = false
                    }
                }) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(showFoldersOnly ? .blue : .secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help(showFoldersOnly ? "Showing folder patterns only (click to show all)" : "Show folder patterns only")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Sort Controls
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
                
                Spacer()
                
                if showFilesOnly || showFoldersOnly {
                    Text("\(filteredPatterns.count) of \(patterns.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Pattern List
            List(filteredPatterns, selection: $selectedPatterns) { pattern in
                FilePatternRow(pattern: pattern)
                    .tag(pattern.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Show detail view on click
                        detailViewPattern = pattern
                        showingDetailView = true
                    }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .sheet(isPresented: $showingDetailView) {
            if let pattern = detailViewPattern {
                FilePatternDetailView(pattern: pattern, isPresented: $showingDetailView)
            }
        }
    }
}

// MARK: - Stats Header
struct StatsHeaderView: View {
    let patterns: [FilePattern]
    
    var totalFiles: Int {
        patterns.reduce(0) { $0 + $1.count }
    }
    
    var totalSize: String {
        let bytes = patterns.reduce(0) { $0 + $1.totalSize }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    var body: some View {
        HStack(spacing: 30) {
            StatItem(
                icon: "folder.fill",
                label: "Patterns",
                value: "\(patterns.count)",
                color: .blue
            )
            
            StatItem(
                icon: "doc.fill",
                label: "Files",
                value: "\(totalFiles)",
                color: .orange
            )
            
            StatItem(
                icon: "internaldrive.fill",
                label: "Total Size",
                value: totalSize,
                color: .purple
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
        }
    }
}

// MARK: - Pattern Row
struct FilePatternRow: View {
    let pattern: FilePattern
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Safety Icon
            Image(systemName: safetyIcon)
                .font(.title2)
                .foregroundStyle(safetyColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 6) {
                // Pattern Name
                HStack {
                    Text(pattern.patternName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Reason
                Text(pattern.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // Stats
                HStack(spacing: 16) {
                    Label("\(pattern.count) items", systemImage: "number")
                    Label(formatSize(pattern.totalSize), systemImage: "internaldrive")
                    Label(pattern.safetyScore.rawValue, systemImage: "shield.fill")
                        .foregroundStyle(safetyColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var safetyIcon: String {
        switch pattern.safetyScore {
        case .high: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .low: return "xmark.shield.fill"
        }
    }
    
    private var safetyColor: Color {
        switch pattern.safetyScore {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
    
    private func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

#Preview {
    FilePatternListView(
        patterns: [
            FilePattern(
                patternName: "node_modules",
                paths: ["/Users/test/project1/node_modules"],
                safetyScore: .high,
                reason: "Standard npm package cache, safe to delete",
                count: 1,
                totalSize: 150_000_000
            ),
            FilePattern(
                patternName: "build",
                paths: ["/Users/test/project1/build"],
                safetyScore: .high,
                reason: "Build artifacts that can be regenerated",
                count: 1,
                totalSize: 50_000_000
            )
        ],
        selectedPatterns: .constant([]),
        searchQuery: ""
    )
}

