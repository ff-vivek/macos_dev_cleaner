import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = FileScanner()
    @StateObject private var aiService = AIService()
    @StateObject private var logManager = LogManager.shared
    @State private var selectedPatterns: Set<String> = []
    @State private var showingDeleteConfirmation = false
    @State private var searchQuery = ""
    @State private var showingLogs = false
    @State private var lastScanDate: String?
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Main Content
            VStack(spacing: 0) {
                // Header
                HeaderView(
                    isScanning: scanner.isScanning,
                    onScan: startScan,
                    onShowLogs: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingLogs.toggle()
                        }
                    },
                    logCount: logManager.logs.count,
                    hasNewLogs: logManager.logs.first?.timestamp.timeIntervalSinceNow ?? -100 > -5,
                    lastScanDate: lastScanDate
                )
                
                Divider()
                
                // Main Content Area
                if scanner.filePatterns.isEmpty && !scanner.isScanning {
                    EmptyStateView()
                } else if scanner.isScanning {
                    LoadingView()
                } else {
                    HSplitView {
                        // File Patterns List
                        FilePatternListView(
                            patterns: scanner.filePatterns,
                            selectedPatterns: $selectedPatterns,
                            searchQuery: searchQuery
                        )
                        .frame(minWidth: 400)
                        
                        // AI Assistant Sidebar
                        AIAssistantView(
                            aiService: aiService,
                            scanner: scanner,
                            selectedPatterns: $selectedPatterns
                        )
                        .frame(minWidth: 300, idealWidth: 350, maxWidth: 500)
                    }
                }
                
                Divider()
                
                // Footer Actions
                FooterView(
                    selectedCount: selectedPatterns.count,
                    totalSize: calculateSelectedSize(),
                    onDelete: {
                        showingDeleteConfirmation = true
                    },
                    onClear: {
                        selectedPatterns.removeAll()
                    }
                )
            }
            .frame(minWidth: 900, minHeight: 600)
            
            // Log Drawer (Sliding from right)
            if showingLogs {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingLogs = false
                        }
                    }
                
                HStack(spacing: 0) {
                    Spacer()
                    
                    LogView(logManager: logManager, isShowing: $showingLogs)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: -5, y: 0)
                        .transition(.move(edge: .trailing))
                }
                .ignoresSafeArea()
            }
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                deleteSelectedPatterns()
            }
        } message: {
            Text("Are you sure you want to move \(selectedPatterns.count) pattern(s) to trash? This will delete approximately \(calculateSelectedSize()).")
        }
        .onAppear {
            loadSavedData()
        }
    }
    
    private func startScan() {
        logManager.log("User initiated scan", level: .info, category: .system)
        selectedPatterns.removeAll()
        
        // Clear previous data for fresh scan
        scanner.filePatterns = []
        aiService.patterns = []
        
        Task {
            // Start background task to update patterns continuously
            let analysisTask = Task {
                await updatePatternsContinuously()
            }
            
            // Scan directories - files are added progressively
            await scanner.scanDirectories()
            
            // Wait for scanning to complete, then cancel analysis task
            analysisTask.cancel()
            
            // Final comprehensive analysis
            if !scanner.discoveredFiles.isEmpty {
                await aiService.analyzeAndGroupFiles(scanner.discoveredFiles)
                scanner.filePatterns = aiService.patterns
                
                // Save scan data
                PersistenceManager.shared.saveScanData(
                    files: scanner.discoveredFiles,
                    patterns: scanner.filePatterns
                )
                lastScanDate = PersistenceManager.shared.getScanDataAge()
            } else {
                logManager.log("No files found during scan", level: .warning, category: .system)
            }
        }
    }
    
    private func updatePatternsContinuously() async {
        // Continuously analyze files as they're being discovered
        var lastFileCount = 0
        
        while scanner.isScanning {
            let currentFileCount = scanner.discoveredFiles.count
            
            // Only update if we have new files
            if currentFileCount > lastFileCount && currentFileCount > 0 {
                await aiService.analyzeAndGroupFiles(scanner.discoveredFiles)
                scanner.filePatterns = aiService.patterns
                lastFileCount = currentFileCount
            }
            
            // Check more frequently for faster updates (0.3 seconds)
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }
    
    private func loadSavedData() {
        logManager.log("Checking for saved scan data", level: .info, category: .system)
        
        if let savedData = PersistenceManager.shared.loadScanData() {
            scanner.discoveredFiles = savedData.files
            scanner.filePatterns = savedData.patterns
            aiService.patterns = savedData.patterns
            lastScanDate = PersistenceManager.shared.getScanDataAge()
            
            logManager.log("Loaded \(savedData.patterns.count) patterns from previous scan", level: .success, category: .system)
        } else {
            logManager.log("No saved data found - please run a scan", level: .info, category: .system)
        }
    }
    
    private func calculateSelectedSize() -> String {
        let totalBytes = scanner.filePatterns
            .filter { selectedPatterns.contains($0.id) }
            .reduce(0) { $0 + $1.totalSize }
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
    
    private func deleteSelectedPatterns() {
        logManager.log("User confirmed deletion of \(selectedPatterns.count) pattern(s)", level: .info, category: .deletion)
        Task {
            for pattern in scanner.filePatterns where selectedPatterns.contains(pattern.id) {
                await scanner.moveToTrash(pattern: pattern)
            }
            selectedPatterns.removeAll()
            
            logManager.log("Starting rescan after deletion", level: .info, category: .system)
            // Rescan after deletion
            await scanner.scanDirectories()
            if !scanner.discoveredFiles.isEmpty {
                await aiService.analyzeAndGroupFiles(scanner.discoveredFiles)
                scanner.filePatterns = aiService.patterns
                
                // Save updated data
                PersistenceManager.shared.saveScanData(
                    files: scanner.discoveredFiles,
                    patterns: scanner.filePatterns
                )
                lastScanDate = PersistenceManager.shared.getScanDataAge()
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    let isScanning: Bool
    let onScan: () -> Void
    let onShowLogs: () -> Void
    let logCount: Int
    let hasNewLogs: Bool
    let lastScanDate: String?
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI File Cleaner")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let lastScan = lastScanDate {
                    Text("Last scan: \(lastScan)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Logs Button
            Button(action: onShowLogs) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                    Text("Logs")
                    if logCount > 0 {
                        Text("\(logCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(hasNewLogs ? Color.green : Color.secondary)
                            .cornerRadius(8)
                    }
                }
            }
            .buttonStyle(.bordered)
            .help("View activity logs")
            
            Button(action: onScan) {
                Label(isScanning ? "Scanning..." : "Scan for Files", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Files Scanned")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Click 'Scan for Files' to start analyzing your system for temporary and build files.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Scanning directories and analyzing with AI...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Footer View
struct FooterView: View {
    let selectedCount: Int
    let totalSize: String
    let onDelete: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            if selectedCount > 0 {
                Text("\(selectedCount) pattern(s) selected • \(totalSize)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Clear Selection", action: onClear)
                    .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Label("Move to Trash", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Text("Select patterns to delete")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    ContentView()
}

