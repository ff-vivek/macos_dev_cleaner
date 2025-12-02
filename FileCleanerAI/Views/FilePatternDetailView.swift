import SwiftUI

struct FilePatternDetailView: View {
    let pattern: FilePattern
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedFiles: Set<String> = []
    @State private var showingDeleteConfirmation = false
    @State private var showFilesOnly = false
    @State private var showFoldersOnly = false
    @State private var sortOrder: SortOrder = .nameAscending
    @State private var sizeCache: [String: Int] = [:]
    @State private var isCalculatingSizes = false
    
    enum SortOrder: String, CaseIterable {
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case sizeDescending = "Size (Largest)"
        case sizeAscending = "Size (Smallest)"
        case typeFilesFirst = "Files First"
        case typeFoldersFirst = "Folders First"
    }
    
    var filteredPaths: [String] {
        var paths = pattern.paths
        
        // Apply search filter
        if !searchText.isEmpty {
            paths = paths.filter { path in
                path.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply file type filters (both can be off, or one at a time)
        if showFilesOnly && !showFoldersOnly {
            paths = paths.filter { !isPathDirectory($0) }
        } else if showFoldersOnly && !showFilesOnly {
            paths = paths.filter { isPathDirectory($0) }
        }
        // If both are on or both are off, show all
        
        // Apply sorting
        paths = sortPaths(paths)
        
        return paths
    }
    
    private func sortPaths(_ paths: [String]) -> [String] {
        switch sortOrder {
        case .nameAscending:
            return paths.sorted { path1, path2 in
                let name1 = (path1 as NSString).lastPathComponent
                let name2 = (path2 as NSString).lastPathComponent
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        case .nameDescending:
            return paths.sorted { path1, path2 in
                let name1 = (path1 as NSString).lastPathComponent
                let name2 = (path2 as NSString).lastPathComponent
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedDescending
            }
        case .sizeDescending:
            // Only sort by size if we have cached sizes
            if !sizeCache.isEmpty {
                return paths.sorted { path1, path2 in
                    let size1 = sizeCache[path1] ?? 0
                    let size2 = sizeCache[path2] ?? 0
                    return size1 > size2
                }
            } else {
                // Start calculating sizes in background
                calculateSizesAsync(for: paths)
                // Return name-sorted while calculating
                return paths.sorted { path1, path2 in
                    let name1 = (path1 as NSString).lastPathComponent
                    let name2 = (path2 as NSString).lastPathComponent
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }
            }
        case .sizeAscending:
            // Only sort by size if we have cached sizes
            if !sizeCache.isEmpty {
                return paths.sorted { path1, path2 in
                    let size1 = sizeCache[path1] ?? 0
                    let size2 = sizeCache[path2] ?? 0
                    return size1 < size2
                }
            } else {
                // Start calculating sizes in background
                calculateSizesAsync(for: paths)
                // Return name-sorted while calculating
                return paths.sorted { path1, path2 in
                    let name1 = (path1 as NSString).lastPathComponent
                    let name2 = (path2 as NSString).lastPathComponent
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }
            }
        case .typeFilesFirst:
            return paths.sorted { path1, path2 in
                let isDir1 = isPathDirectory(path1)
                let isDir2 = isPathDirectory(path2)
                if isDir1 != isDir2 {
                    return !isDir1 // Files (false) come before folders (true)
                }
                // If same type, sort by name
                let name1 = (path1 as NSString).lastPathComponent
                let name2 = (path2 as NSString).lastPathComponent
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        case .typeFoldersFirst:
            return paths.sorted { path1, path2 in
                let isDir1 = isPathDirectory(path1)
                let isDir2 = isPathDirectory(path2)
                if isDir1 != isDir2 {
                    return isDir1 // Folders (true) come before files (false)
                }
                // If same type, sort by name
                let name1 = (path1 as NSString).lastPathComponent
                let name2 = (path2 as NSString).lastPathComponent
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
    }
    
    private func calculateSizesAsync(for paths: [String]) {
        guard !isCalculatingSizes else { return }
        
        isCalculatingSizes = true
        
        Task.detached(priority: .userInitiated) {
            var cache: [String: Int] = [:]
            
            for path in paths {
                let size = await Self.calculatePathSizeAsync(path)
                cache[path] = size
            }
            
            await MainActor.run {
                self.sizeCache = cache
                self.isCalculatingSizes = false
            }
        }
    }
    
    private static func calculatePathSizeAsync(_ path: String) async -> Int {
        let url = URL(fileURLWithPath: path)
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            
            if let isDir = resourceValues.isDirectory, isDir {
                // Calculate directory size
                return calculateDirectorySizeStatic(at: url)
            } else {
                // Return file size
                return resourceValues.fileSize ?? 0
            }
        } catch {
            return 0
        }
    }
    
    private static func calculateDirectorySizeStatic(at url: URL) -> Int {
        let fileManager = FileManager.default
        var totalSize = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    private func isPathDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    var totalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(pattern.totalSize), countStyle: .file)
    }
    
    var selectedSize: Int {
        let paths = Array(selectedFiles)
        var totalSize = 0
        
        for path in paths {
            // Use cached size if available, otherwise use 0
            totalSize += sizeCache[path] ?? 0
        }
        
        return totalSize
    }
    
    var selectedSizeString: String {
        if selectedSize > 0 {
            return ByteCountFormatter.string(fromByteCount: Int64(selectedSize), countStyle: .file)
        } else if !selectedFiles.isEmpty && sizeCache.isEmpty {
            return "Calculating..."
        } else {
            return "0 bytes"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.patternName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Label("\(pattern.count) items", systemImage: "doc.fill")
                        Label(totalSize, systemImage: "internaldrive")
                        Label(pattern.safetyScore.rawValue, systemImage: safetyIcon)
                            .foregroundStyle(safetyColor)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close detail view")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Safety Info
            HStack {
                Image(systemName: safetyIcon)
                    .foregroundStyle(safetyColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safety Assessment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pattern.reason)
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .padding()
            .background(safetyColor.opacity(0.1))
            
            Divider()
            
            // Search Bar with Toggleable Filter Icons
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search files and folders...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
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
                .help(showFilesOnly ? "Showing files only (click to show all)" : "Show files only")
                
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
                .help(showFoldersOnly ? "Showing folders only (click to show all)" : "Show folders only")
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                Text("\(filteredPaths.count) of \(pattern.paths.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
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
                
                if isCalculatingSizes && (sortOrder == .sizeDescending || sortOrder == .sizeAscending) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, 4)
                    Text("Calculating sizes...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if showFilesOnly || showFoldersOnly || !searchText.isEmpty {
                    Text("\(filteredPaths.count) of \(pattern.paths.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Files List
            if filteredPaths.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No files match your search")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredPaths, id: \.self, selection: $selectedFiles) { path in
                    FilePathRow(path: path)
                        .onTapGesture(count: 2) {
                            openInFinder(path: path)
                        }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Footer with selection actions
            HStack {
                if selectedFiles.isEmpty {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    
                    Text("Double-click to open in Finder • Select files to delete individually")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedFiles.count) of \(pattern.paths.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Total: \(selectedSizeString)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    Button("Clear Selection") {
                        selectedFiles.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        Label("Delete Selected", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 700, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                deleteSelectedFiles()
            }
        } message: {
            Text("Are you sure you want to move \(selectedFiles.count) item(s) (\(selectedSizeString)) to trash?")
        }
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
    
    private func deleteSelectedFiles() {
        let filesToDelete = Array(selectedFiles)
        
        Task { @MainActor in
            LogManager.shared.log("Deleting \(filesToDelete.count) individual files from pattern '\(pattern.patternName)'", level: .info, category: .deletion)
            
            let fileManager = FileManager.default
            var successCount = 0
            var failCount = 0
            
            for path in filesToDelete {
                do {
                    let url = URL(fileURLWithPath: path)
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                    successCount += 1
                    LogManager.shared.log("Moved to trash: \(path)", level: .success, category: .deletion)
                } catch {
                    failCount += 1
                    LogManager.shared.log("Failed to trash: \(path) - \(error.localizedDescription)", level: .error, category: .deletion)
                }
            }
            
            if failCount == 0 {
                LogManager.shared.log("Successfully moved \(successCount) items to trash", level: .success, category: .deletion)
            } else {
                LogManager.shared.log("Completed with \(successCount) successes and \(failCount) failures", level: .warning, category: .deletion)
            }
            
            // Clear selection and close
            selectedFiles.removeAll()
            isPresented = false
        }
    }
    
    private func openInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        LogManager.shared.log("Opened in Finder: \(path)", level: .info, category: .general)
    }
}

// MARK: - File Path Row
struct FilePathRow: View {
    let path: String
    @State private var fileSize: String = "Calculating..."
    @State private var isDirectory: Bool = false
    
    var displayPath: String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
    
    var fileName: String {
        (path as NSString).lastPathComponent
    }
    
    var directoryPath: String {
        (path as NSString).deletingLastPathComponent
            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(isDirectory ? .blue : .secondary)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                // File/Folder name
                Text(fileName)
                    .font(.body)
                    .lineLimit(1)
                
                // Directory path
                Text(directoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Size
                Text(fileSize)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .onAppear {
            loadFileInfo()
        }
    }
    
    private func loadFileInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: path)
            
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                
                let isDirValue = resourceValues.isDirectory ?? false
                let size: Int
                
                if isDirValue {
                    size = Self.calculateDirectorySizeStatic(at: url)
                } else {
                    size = resourceValues.fileSize ?? 0
                }
                
                let sizeString = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                
                DispatchQueue.main.async {
                    self.isDirectory = isDirValue
                    self.fileSize = sizeString
                }
            } catch {
                DispatchQueue.main.async {
                    self.fileSize = "Unknown"
                }
            }
        }
    }
    
    nonisolated private static func calculateDirectorySizeStatic(at url: URL) -> Int {
        let fileManager = FileManager.default
        var totalSize = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += size
            }
        }
        
        return totalSize
    }
}

#Preview {
    FilePatternDetailView(
        pattern: FilePattern(
            patternName: "node_modules",
            paths: [
                "/Users/test/project1/node_modules",
                "/Users/test/project2/node_modules",
                "/Users/test/old-project/node_modules"
            ],
            safetyScore: .high,
            reason: "NPM package cache that can be regenerated with npm install",
            count: 3,
            totalSize: 250_000_000
        ),
        isPresented: .constant(true)
    )
}
