# Changelog

All notable changes to AI File Cleaner will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-02

### Added
- Initial release
- Smart file pattern detection with AI and rule-based analysis
- Progressive scanning with real-time updates
- File and folder filtering with toggleable icons
- Multiple sorting options (name, size, type)
- Individual file selection and deletion
- Multi-select functionality
- Double-click to open files/folders in Finder
- Async size calculations with caching
- Comprehensive logging system with drawer UI
- Data persistence across sessions
- AI chat assistant (requires macOS 26.0+)
- Safety scoring (High/Medium/Low)
- Search functionality with live filtering
- Pattern detail view with search
- Export logs capability

### Features
- Detects: node_modules, build artifacts, caches, temp files, logs
- Safe deletion (moves to Trash)
- 100% local processing (no network calls)
- Privacy-focused design
- macOS 15.0+ support

### Technical
- MVVM architecture
- SwiftUI interface
- Async/await for performance
- FoundationModels integration
- Size caching for optimization
- Thread-safe operations

---

## Release Notes

### v1.0.0 - First Public Release

A powerful, privacy-focused file cleaner for macOS that uses on-device AI to help you safely identify and delete temporary files, build artifacts, and space-consuming files.

**Highlights:**
- 🤖 On-device AI with intelligent fallback
- 🔍 Smart pattern detection
- 🛡️ Safety scoring system
- ⚡ Progressive real-time scanning
- 🎯 Granular control over deletions
- 🔒 100% private and local

Perfect for developers and power users looking to reclaim disk space safely!

