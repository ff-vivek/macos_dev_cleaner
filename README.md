# AI File Cleaner

An intelligent macOS application that uses on-device AI to help you find and safely delete temporary files, build artifacts, and other space-consuming files.

## Features

- 🤖 **On-Device AI** - Privacy-focused local AI processing with rule-based fallback
- 🔍 **Smart Detection** - Automatically identifies temp files, build artifacts, node_modules, caches
- 🛡️ **Safety Scoring** - AI analyzes each file pattern and provides safety ratings
- 💬 **Natural Language** - Chat with AI to understand your files
- 📊 **Visual Analytics** - File patterns grouped by type, size, and safety
- 🗑️ **Safe Deletion** - Moves files to Trash (not permanent deletion)
- 🔎 **Advanced Search** - Filter by files/folders, sort by name/size/type
- ⚡ **Progressive Scanning** - Real-time updates as files are discovered

## Requirements

- macOS 15.0 or later
- Apple Silicon recommended for AI features (M1/M2/M3/M4)

## Building & Running

### Quick Start
```bash
# Build and run
./build_app.sh -o

# Create DMG installer
./build_app.sh --dmg

# See all options
./build_app.sh --help
```

### Using Xcode
```bash
open Package.swift
# Press ⌘R to build and run
```

## Usage

1. **Scan** - Click "Scan for Files" to analyze your system
2. **Review** - AI groups files into patterns with safety scores:
   - 🟢 High Safety: Build artifacts, dependencies (safe to delete)
   - 🟡 Medium Safety: Temp files, logs (usually safe)
   - 🔴 Low Safety: Review carefully before deletion
3. **Ask AI** - Use the AI Assistant to understand files
4. **Delete** - Select patterns and move them to Trash

## What It Finds

- `node_modules` (npm packages)
- `build`, `target`, `dist` (build artifacts)
- `.gradle`, `Pods`, `DerivedData` (dependency caches)
- `__pycache__`, `.pytest_cache` (Python temp files)
- `.log`, `.tmp`, `.cache` files
- `.zip`, `.tar.gz` archives
- `.DS_Store` files

## Privacy & Safety

- ✅ 100% local processing - No data sent to external servers
- ✅ Safe deletion - Files moved to Trash, not permanently deleted
- ✅ No system files - Skips critical system directories
- ✅ Transparent - Shows exactly what will be deleted

## Project Structure

```
FileCleanerAI/
├── FileCleanerAI/
│   ├── FileCleanerAIApp.swift       # Main app entry
│   ├── Views/                        # UI components
│   │   ├── ContentView.swift
│   │   ├── FileListView.swift
│   │   ├── FilePatternDetailView.swift
│   │   ├── AIAssistantView.swift
│   │   └── LogView.swift
│   ├── Models/                       # Data models
│   │   ├── FileItem.swift
│   │   ├── AIService.swift
│   │   └── LogManager.swift
│   └── Utils/                        # Utilities
│       ├── FileScanner.swift
│       └── PersistenceManager.swift
├── Package.swift
├── build_app.sh                      # Build script
└── README.md
```

## Distribution

### For Development
```bash
./build_app.sh -o
```

### For Distribution
1. Get Apple Developer ID ($99/year)
2. Sign the app:
   ```bash
   codesign --deep --force --sign "Developer ID Application" ".build/release/AI File Cleaner.app"
   ```
3. Notarize:
   ```bash
   xcrun notarytool submit ".build/release/AI File Cleaner.app" --wait
   xcrun stapler staple ".build/release/AI File Cleaner.app"
   ```

## License

MIT License - Feel free to modify and distribute

## Version

**1.0.0** - Production ready

---

Made with ❤️ for macOS
