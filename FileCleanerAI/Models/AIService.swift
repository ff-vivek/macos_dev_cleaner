import Foundation
import FoundationModels

// MARK: - Generable Structures for Type-Safe AI Outputs

@available(macOS 26.0, *)
@Generable
struct FilePatternAnalysis: Codable {
    var patternName: String
    var safetyScore: String
    var reason: String
    var matchingFiles: [String]
}

@available(macOS 26.0, *)
@Generable
struct FileAnalysisResponse: Codable {
    var patterns: [FilePatternAnalysis]
}

// MARK: - AI Service

@MainActor
class AIService: ObservableObject {
    @Published var patterns: [FilePattern] = []
    @Published var chatHistory: [ChatMessage] = []
    @Published var isProcessing = false
    
    private let logManager = LogManager.shared
    
    // Language model session for AI-powered analysis (type-erased for compatibility)
    private var modelSessionStorage: Any?
    private var hasAI = false
    
    @available(macOS 26.0, *)
    private var modelSession: LanguageModelSession? {
        get { modelSessionStorage as? LanguageModelSession }
        set { modelSessionStorage = newValue }
    }
    
    init() {
        setupLanguageModel()
    }
    
    private func setupLanguageModel() {
        // Try to load FoundationModels on macOS 26.0+
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            
            // Check model availability
            guard model.availability == .available else {
            hasAI = false
            logManager.log("Using rule-based file analysis", level: .info, category: .ai)
            logManager.log("FoundationModels not available on this device", level: .warning, category: .ai)
            return
            }
            
            // Initialize session with instructions
            modelSession = LanguageModelSession(
                model: model,
                instructions: """
                You are an AI assistant specialized in analyzing temporary files and build artifacts on macOS systems.
                Your role is to:
                1. Identify file patterns (node_modules, build directories, caches, etc.)
                2. Assess deletion safety (High/Medium/Low)
                3. Provide clear, concise explanations
                4. Help users reclaim disk space safely
                
                Be direct, factual, and focus on file safety. Keep responses under 3 sentences.
                """
            )
            
            hasAI = true
            logManager.log("AI-powered analysis enabled (FoundationModels)", level: .success, category: .ai)
            logManager.log("Using on-device language model for intelligent file analysis", level: .info, category: .ai)
            
            // Pre-warm the model for better performance
            Task {
                await prewarmModel()
            }
        } else {
            hasAI = false
            logManager.log("Using rule-based file analysis", level: .info, category: .ai)
            logManager.log("Requires macOS 26.0+ for AI features", level: .warning, category: .ai)
        }
    }
    
    // MARK: - Model Management
    
    @available(macOS 26.0, *)
    private func prewarmModel() async {
        guard let session = modelSession else { return }
        
        do {
            // Pre-warm with a simple query to reduce first-use latency
            _ = try await session.respond(to: "Ready")
            logManager.log("AI model pre-warmed and ready", level: .success, category: .ai)
        } catch {
            logManager.log("Model pre-warming failed: \(error.localizedDescription)", level: .warning, category: .ai)
        }
    }
    
    // MARK: - File Analysis
    
    func analyzeAndGroupFiles(_ files: [DiscoveredFile]) async {
        guard !files.isEmpty else {
            logManager.log("No files to analyze", level: .warning, category: .ai)
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        logManager.log("Starting analysis of \(files.count) files", level: .info, category: .ai)
        
        // Use rule-based grouping for immediate results (AI is too slow for progressive updates)
        analyzeWithRules(files)
        
        logManager.log("Analysis complete: Found \(patterns.count) patterns", level: .success, category: .ai)
    }
    
    @available(macOS 26.0, *)
    private func analyzeWithAI(_ files: [DiscoveredFile], session: LanguageModelSession) async {
        // Validate input
        guard !files.isEmpty else {
            logManager.log("No files to analyze", level: .warning, category: .ai)
            return
        }
        
        logManager.log("Sending \(files.count) files to AI for analysis", level: .info, category: .ai)
        
        // Prepare file summary for AI analysis
        let fileSummary = createFileSummary(files)
        
        guard !fileSummary.isEmpty else {
            logManager.log("Failed to create file summary", level: .error, category: .ai)
            analyzeWithRules(files)
            return
        }
        
        let prompt = """
        Analyze these files and group them into patterns. For each pattern, determine:
        1. A descriptive pattern name
        2. Safety score (High/Medium/Low) for deletion
        3. A clear reason why it's safe or unsafe to delete
        4. Which files match this pattern
        
        Files to analyze:
        \(fileSummary)
        
        Common safe patterns include: node_modules, build artifacts, .gradle, Pods, DerivedData, __pycache__, .log files, .tmp files, .cache files, .DS_Store
        """
        
        do {
            // Request structured JSON output
            let enhancedPrompt = """
            \(prompt)
            
            Respond with ONLY valid JSON in this exact format (no markdown, no explanation):
            {
              "patterns": [
                {
                  "patternName": "string",
                  "safetyScore": "High|Medium|Low",
                  "reason": "string",
                  "matchingFiles": ["string"]
                }
              ]
            }
            """
            
            // Get AI response
            let response = try await session.respond(to: enhancedPrompt)
            let jsonString = response.content
            
            // Parse JSON response
            guard let jsonData = jsonString.data(using: .utf8) else {
                logManager.log("Failed to convert AI response to data", level: .error, category: .ai)
                analyzeWithRules(files)
                return
            }
            
            logManager.log("AI analysis completed successfully", level: .success, category: .ai)
            
            // Decode using our @Generable structure
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            
            let analysisResponse = try decoder.decode(FileAnalysisResponse.self, from: jsonData)
            
            // Validate AI response
            guard !analysisResponse.patterns.isEmpty else {
                logManager.log("AI returned empty analysis, using rule-based fallback", level: .warning, category: .ai)
                analyzeWithRules(files)
                return
            }
            
            // Convert AI response to FilePattern objects
            patterns = analysisResponse.patterns.compactMap { aiPattern -> FilePattern? in
                // Validate pattern data
                guard !aiPattern.patternName.isEmpty,
                      !aiPattern.matchingFiles.isEmpty else {
                    return nil as FilePattern?
                }
                
                let matchedFiles = files.filter { file in
                    aiPattern.matchingFiles.contains(file.path)
                }
                let totalSize = matchedFiles.reduce(0) { $0 + $1.size }
                
                return FilePattern(
                    patternName: aiPattern.patternName,
                    paths: aiPattern.matchingFiles,
                    safetyScore: SafetyScore(rawValue: aiPattern.safetyScore) ?? .medium,
                    reason: aiPattern.reason,
                    count: aiPattern.matchingFiles.count,
                    totalSize: totalSize
                )
            }
            .sorted { $0.totalSize > $1.totalSize }
            
            logManager.log("AI analysis complete: \(patterns.count) patterns identified", level: .success, category: .ai)
            
        } catch let error as NSError {
            // Detailed error handling
            logManager.log("AI analysis failed: \(error.localizedDescription)", level: .error, category: .ai)
            logManager.log("Error domain: \(error.domain), code: \(error.code)", level: .debug, category: .ai)
            logManager.log("Falling back to rule-based analysis", level: .warning, category: .ai)
            analyzeWithRules(files)
        } catch {
            logManager.log("AI analysis failed with unexpected error: \(error)", level: .error, category: .ai)
            logManager.log("Falling back to rule-based analysis", level: .warning, category: .ai)
            analyzeWithRules(files)
        }
    }
    
    private func analyzeWithRules(_ files: [DiscoveredFile]) {
        logManager.log("Using rule-based analysis for \(files.count) files", level: .info, category: .ai)
        logManager.log("Analyzing files by patterns and extensions", level: .debug, category: .ai)
        var groupedPatterns: [String: [DiscoveredFile]] = [:]
        
        // Group by common patterns
        for file in files {
            let fileName = (file.path as NSString).lastPathComponent
            var matched = false
            
            // Check against known patterns
            for pattern in ScanConfiguration.commonTempPatterns {
                if fileName.contains(pattern) {
                    groupedPatterns[pattern, default: []].append(file)
                    matched = true
                    break
                }
            }
            
            // Check file extensions
            if !matched {
                for ext in ScanConfiguration.fileExtensions {
                    if fileName.hasSuffix(ext) {
                        let key = "*\(ext) files"
                        groupedPatterns[key, default: []].append(file)
                        matched = true
                        break
                    }
                }
            }
            
            // Other files
            if !matched {
                groupedPatterns["Other temporary files", default: []].append(file)
            }
        }
        
        // Convert to FilePattern objects
        logManager.log("Creating patterns from \(groupedPatterns.count) groups", level: .debug, category: .ai)
        patterns = groupedPatterns.map { key, files in
            let totalSize = files.reduce(0) { $0 + $1.size }
            let safety = determineSafety(for: key)
            let reason = generateReason(for: key, safety: safety)
            
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
            logManager.log("Pattern '\(key)': \(files.count) items, \(sizeStr), Safety: \(safety.rawValue)", level: .info, category: .ai)
            
            return FilePattern(
                patternName: key,
                paths: files.map { $0.path },
                safetyScore: safety,
                reason: reason,
                count: files.count,
                totalSize: totalSize
            )
        }
        .sorted { $0.totalSize > $1.totalSize }
        
        logManager.log("Rule-based analysis created \(patterns.count) patterns", level: .success, category: .ai)
    }
    
    // MARK: - Natural Language Processing
    
    func processNaturalLanguageQuery(_ query: String, patterns: [FilePattern]) async -> String {
        if #available(macOS 26.0, *), hasAI, let session = modelSession {
            // Use AI for intelligent responses
            return await handleQueryWithAI(query, patterns: patterns, session: session)
        } else {
            // Fallback to rule-based responses
            return handleQueryWithRules(query, patterns: patterns)
        }
    }
    
    @available(macOS 26.0, *)
    private func handleQueryWithAI(_ query: String, patterns: [FilePattern], session: LanguageModelSession) async -> String {
        // Validate input
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Please ask a question about the files."
        }
        
        let patternsContext = createPatternsContext(patterns)
        
        guard !patternsContext.isEmpty else {
            return "No file patterns have been detected yet. Please scan for files first."
        }
        
        let prompt = """
        Current file patterns detected:
        \(patternsContext)
        
        User question: \(query)
        """
        
        do {
            // Get AI response (streaming will be added when API supports it)
            let response = try await session.respond(to: prompt)
            let fullResponse = response.content
            
            // Validate response
            guard !fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                logManager.log("AI returned empty response, using rule-based fallback", level: .warning, category: .ai)
                return handleQueryWithRules(query, patterns: patterns)
            }
            
            logManager.log("AI response generated successfully", level: .success, category: .ai)
            return fullResponse
            
        } catch let error as NSError {
            logManager.log("AI query failed: \(error.localizedDescription)", level: .error, category: .ai)
            logManager.log("Error domain: \(error.domain), Using rule-based response", level: .debug, category: .ai)
            return handleQueryWithRules(query, patterns: patterns)
        } catch {
            logManager.log("AI query failed: \(error)", level: .error, category: .ai)
            return handleQueryWithRules(query, patterns: patterns)
        }
    }
    
    private func handleQueryWithRules(_ query: String, patterns: [FilePattern]) -> String {
        let lowercaseQuery = query.lowercased()
        
        if lowercaseQuery.contains("safe") || lowercaseQuery.contains("delete") {
            let safePatterns = patterns.filter { $0.safetyScore == .high }
            if safePatterns.isEmpty {
                return "No patterns were identified as highly safe to delete."
            }
            let names = safePatterns.prefix(3).map { "• \($0.patternName)" }.joined(separator: "\n")
            return "These patterns are safe to delete:\n\(names)"
        }
        
        if lowercaseQuery.contains("largest") || lowercaseQuery.contains("space") || lowercaseQuery.contains("big") {
            let largest = patterns.prefix(3)
            let info = largest.map {
                let size = ByteCountFormatter.string(fromByteCount: Int64($0.totalSize), countStyle: .file)
                return "• \($0.patternName): \(size)"
            }.joined(separator: "\n")
            return "Largest patterns:\n\(info)"
        }
        
        return "I can help you understand which files are safe to delete and what's taking up space. Try asking 'What's safe to delete?' or 'Show me the largest files'."
    }
    
    // MARK: - Helper Methods
    
    private func createFileSummary(_ files: [DiscoveredFile]) -> String {
        let maxFiles = 100 // Limit for AI context
        let limitedFiles = Array(files.prefix(maxFiles))
        
        return limitedFiles.map { file in
            let size = ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)
            let type = file.isDirectory ? "DIR" : "FILE"
            return "[\(type)] \(file.displayPath) (\(size))"
        }.joined(separator: "\n")
    }
    
    private func createPatternsContext(_ patterns: [FilePattern]) -> String {
        patterns.map { pattern in
            let size = ByteCountFormatter.string(fromByteCount: Int64(pattern.totalSize), countStyle: .file)
            return "• \(pattern.patternName): \(pattern.count) items, \(size), Safety: \(pattern.safetyScore.rawValue)"
        }.joined(separator: "\n")
    }
    
    private func determineSafety(for pattern: String) -> SafetyScore {
        let highSafetyPatterns = ["node_modules", "build", ".gradle", "target", "dist", "__pycache__", "Pods", "DerivedData"]
        let mediumSafetyPatterns = [".log", ".tmp", ".cache", ".DS_Store"]
        
        if highSafetyPatterns.contains(where: { pattern.contains($0) }) {
            return .high
        } else if mediumSafetyPatterns.contains(where: { pattern.contains($0) }) {
            return .medium
        }
        return .low
    }
    
    private func generateReason(for pattern: String, safety: SafetyScore) -> String {
        switch safety {
        case .high:
            return "Build artifacts or dependencies that can be regenerated"
        case .medium:
            return "Temporary files that are typically safe to remove"
        case .low:
            return "Review carefully before deletion"
        }
    }
}
