import Foundation
import AppKit

@MainActor
class FileScanner: ObservableObject {
    @Published var discoveredFiles: [DiscoveredFile] = []
    @Published var filePatterns: [FilePattern] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    
    private let fileManager = FileManager.default
    private let logManager = LogManager.shared
    
    // MARK: - Scanning
    
    func scanDirectories() async {
        logManager.log("Starting directory scan", level: .info, category: .scanning)
        isScanning = true
        discoveredFiles.removeAll()
        scanProgress = 0.0
        
        defer {
            isScanning = false
            scanProgress = 1.0
        }
        
        // Expand home directory paths
        let directories = ScanConfiguration.defaultDirectories.map { dir in
            (dir as NSString).expandingTildeInPath
        }
        
        logManager.log("Scanning \(directories.count) directories", level: .info, category: .scanning)
        let totalDirs = Double(directories.count)
        
        for (index, directory) in directories.enumerated() {
            logManager.log("Scanning: \(directory)", level: .info, category: .scanning)
            await scanDirectory(directory)
            scanProgress = Double(index + 1) / totalDirs
            
            // Yield to allow UI updates after each directory
            await Task.yield()
        }
        
        logManager.log("Scan complete: Found \(discoveredFiles.count) files", level: .success, category: .scanning)
    }
    
    private func scanDirectory(_ path: String) async {
        guard fileManager.fileExists(atPath: path) else {
            logManager.log("Directory does not exist: \(path)", level: .warning, category: .scanning)
            return
        }
        
        logManager.log("Searching for patterns in: \(path)", level: .debug, category: .scanning)
        
        // Scan for common temporary patterns - files are added immediately
        for pattern in ScanConfiguration.commonTempPatterns {
            logManager.log("Looking for pattern: \(pattern)", level: .debug, category: .scanning)
            await findFiles(in: path, matching: pattern)
            // Small yield after each pattern to allow UI updates
            await Task.yield()
        }
        
        // Scan for file extensions - files are added immediately
        for ext in ScanConfiguration.fileExtensions {
            logManager.log("Looking for extension: \(ext)", level: .debug, category: .scanning)
            await findFiles(in: path, withExtension: ext)
            // Small yield after each extension to allow UI updates
            await Task.yield()
        }
    }
    
    private func findFiles(in directory: String, matching pattern: String) async {
        // Perform enumeration in a detached task to avoid actor isolation issues
        let foundFiles: [DiscoveredFile] = await Task.detached { () -> [DiscoveredFile] in
            let url = URL(fileURLWithPath: directory)
            let fileManager = FileManager.default
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return [] }
            
            // Convert enumerator to array to avoid async iteration issues
            let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
            var files: [DiscoveredFile] = []
            
            for fileURL in allURLs {
                // Skip system directories
                if Self.shouldSkipPathStatic(fileURL.path) {
                    continue
                }
                
                let fileName = fileURL.lastPathComponent
                
                // Match pattern
                if fileName == pattern || fileName.contains(pattern) {
                    if let file = Self.createDiscoveredFileStatic(from: fileURL, fileManager: fileManager) {
                        files.append(file)
                    }
                }
            }
            
            return files
        }.value
        
        // Add found files immediately - this triggers UI update
        if !foundFiles.isEmpty {
            discoveredFiles.append(contentsOf: foundFiles)
            
            // Log findings
            let totalSize = foundFiles.reduce(0) { $0 + $1.size }
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
            logManager.log("Found \(foundFiles.count) items matching '\(pattern)' (\(sizeStr))", level: .info, category: .scanning)
            
            // Log individual files found (only first few to avoid spam)
            for file in foundFiles.prefix(3) {
                let size = ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)
                logManager.log("  → \(file.displayPath) (\(size))", level: .debug, category: .scanning)
            }
            if foundFiles.count > 3 {
                logManager.log("  → ... and \(foundFiles.count - 3) more", level: .debug, category: .scanning)
            }
        }
    }
    
    private func findFiles(in directory: String, withExtension ext: String) async {
        // Perform enumeration in a detached task to avoid actor isolation issues
        let foundFiles: [DiscoveredFile] = await Task.detached { () -> [DiscoveredFile] in
            let url = URL(fileURLWithPath: directory)
            let fileManager = FileManager.default
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            
            // Convert enumerator to array to avoid async iteration issues
            let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
            var files: [DiscoveredFile] = []
            
            for fileURL in allURLs {
                if Self.shouldSkipPathStatic(fileURL.path) {
                    continue
                }
                
                if fileURL.pathExtension == ext.replacingOccurrences(of: ".", with: "") {
                    if let file = Self.createDiscoveredFileStatic(from: fileURL, fileManager: fileManager) {
                        files.append(file)
                    }
                }
            }
            
            return files
        }.value
        
        // Add found files immediately - this triggers UI update
        if !foundFiles.isEmpty {
            discoveredFiles.append(contentsOf: foundFiles)
            
            // Log findings
            let totalSize = foundFiles.reduce(0) { $0 + $1.size }
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
            logManager.log("Found \(foundFiles.count) files with extension '\(ext)' (\(sizeStr))", level: .info, category: .scanning)
            
            // Log individual files found (only first few to avoid spam)
            for file in foundFiles.prefix(3) {
                let size = ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)
                logManager.log("  → \(file.displayPath) (\(size))", level: .debug, category: .scanning)
            }
            if foundFiles.count > 3 {
                logManager.log("  → ... and \(foundFiles.count - 3) more", level: .debug, category: .scanning)
            }
        }
    }
    
    // MARK: - Deletion
    
    func moveToTrash(pattern: FilePattern) async {
        logManager.log("Moving pattern '\(pattern.patternName)' to trash (\(pattern.count) items)", level: .info, category: .deletion)
        var successCount = 0
        var failCount = 0
        
        for path in pattern.paths {
            do {
                let url = URL(fileURLWithPath: path)
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                successCount += 1
                logManager.log("Moved to trash: \(path)", level: .success, category: .deletion)
            } catch {
                failCount += 1
                logManager.log("Failed to trash: \(path) - \(error.localizedDescription)", level: .error, category: .deletion)
            }
        }
        
        if failCount == 0 {
            logManager.log("Successfully moved \(successCount) items to trash", level: .success, category: .deletion)
        } else {
            logManager.log("Completed with \(successCount) successes and \(failCount) failures", level: .warning, category: .deletion)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createDiscoveredFile(from url: URL) -> DiscoveredFile? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .isDirectoryKey,
                .contentModificationDateKey
            ])
            
            let size: Int
            if let isDirectory = resourceValues.isDirectory, isDirectory {
                size = directorySize(at: url)
            } else {
                size = resourceValues.fileSize ?? 0
            }
            
            return DiscoveredFile(
                path: url.path,
                size: size,
                name: url.lastPathComponent,
                isDirectory: resourceValues.isDirectory ?? false,
                modificationDate: resourceValues.contentModificationDate
            )
        } catch {
            return nil
        }
    }
    
    private func directorySize(at url: URL) -> Int {
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
    
    private func shouldSkipPath(_ path: String) -> Bool {
        return Self.shouldSkipPathStatic(path)
    }
    
    nonisolated private static func shouldSkipPathStatic(_ path: String) -> Bool {
        // Skip system and sensitive directories
        let skipPaths = [
            "/System",
            "/Library/System",
            "/private",
            "/Applications",
            "/usr",
            "/bin",
            "/sbin",
            "/dev",
            "Library/Application Support",
            "Library/Preferences"
        ]
        
        return skipPaths.contains { path.contains($0) }
    }
    
    nonisolated private static func createDiscoveredFileStatic(from url: URL, fileManager: FileManager) -> DiscoveredFile? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .isDirectoryKey,
                .contentModificationDateKey
            ])
            
            let size: Int
            if let isDirectory = resourceValues.isDirectory, isDirectory {
                // Reading directory size
                size = directorySizeStatic(at: url, fileManager: fileManager)
            } else {
                // Reading file size
                size = resourceValues.fileSize ?? 0
            }
            
            return DiscoveredFile(
                path: url.path,
                size: size,
                name: url.lastPathComponent,
                isDirectory: resourceValues.isDirectory ?? false,
                modificationDate: resourceValues.contentModificationDate
            )
        } catch {
            // Error reading file attributes
            return nil
        }
    }
    
    nonisolated private static func directorySizeStatic(at url: URL, fileManager: FileManager) -> Int {
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

