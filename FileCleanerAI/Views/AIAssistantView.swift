import SwiftUI

struct AIAssistantView: View {
    @ObservedObject var aiService: AIService
    @ObservedObject var scanner: FileScanner
    @Binding var selectedPatterns: Set<String>
    @State private var userQuery = ""
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(.purple)
                
                Text("AI Assistant")
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Chat History
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 16) {
                        if aiService.chatHistory.isEmpty {
                            WelcomeMessageView()
                        } else {
                            ForEach(aiService.chatHistory) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if isProcessing {
                            TypingIndicatorView()
                        }
                    }
                    .padding()
                    .onChange(of: aiService.chatHistory.count) {
                        if let last = aiService.chatHistory.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Input Area
            HStack(spacing: 12) {
                TextField("Ask AI about files...", text: $userQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendQuery()
                    }
                
                Button(action: sendQuery) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(userQuery.isEmpty || isProcessing)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func sendQuery() {
        guard !userQuery.isEmpty else { return }
        
        let query = userQuery
        userQuery = ""
        isProcessing = true
        
        // Add user message
        aiService.chatHistory.append(
            ChatMessage(text: query, isUser: true)
        )
        
        Task {
            // Process with AI
            let response = await aiService.processNaturalLanguageQuery(
                query,
                patterns: scanner.filePatterns
            )
            
            // Add AI response
            aiService.chatHistory.append(
                ChatMessage(text: response, isUser: false)
            )
            
            isProcessing = false
        }
    }
}

// MARK: - Welcome Message
struct WelcomeMessageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("👋 Hi! I'm your AI assistant")
                .font(.headline)
            
            Text("I can help you understand and manage temporary files. Try asking:")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                SuggestionChip(text: "What files are safe to delete?")
                SuggestionChip(text: "Show me the largest patterns")
                SuggestionChip(text: "What's taking up the most space?")
                SuggestionChip(text: "Explain the build artifacts")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SuggestionChip: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "sparkle")
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Chat Bubble
struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color(NSColor.controlBackgroundColor))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .cornerRadius(12)
                    .textSelection(.enabled)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(animationAmount == Double(index) ? 1.0 : 0.3)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationAmount = 2.0
            }
        }
    }
}

#Preview {
    AIAssistantView(
        aiService: AIService(),
        scanner: FileScanner(),
        selectedPatterns: .constant([])
    )
    .frame(width: 350, height: 600)
}

