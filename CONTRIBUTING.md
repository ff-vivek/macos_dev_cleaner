# Contributing to AI File Cleaner

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/FileCleanerAI.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Commit: `git commit -m "Add your feature"`
7. Push: `git push origin feature/your-feature-name`
8. Open a Pull Request

## Development Setup

### Requirements
- macOS 15.0+
- Xcode 15.2+
- Swift 6.0+

### Build & Run
```bash
./build_app.sh -d -o   # Debug mode with auto-open
```

## Code Guidelines

### Swift Style
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Keep functions focused and under 50 lines when possible
- Add comments for complex logic

### Architecture
- MVVM pattern
- SwiftUI for all views
- Async/await for asynchronous operations
- @MainActor for UI-related code

### Testing
- Test all new features
- Ensure no regressions
- Test on macOS 15.0 minimum

## What to Contribute

### Good First Issues
- UI improvements
- Additional file patterns
- Bug fixes
- Documentation improvements

### Feature Ideas
- Additional scan locations
- Custom rules engine
- Export capabilities
- Keyboard shortcuts

### Bug Reports
When reporting bugs, include:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Logs (if applicable)

## Pull Request Process

1. **Update README** if needed
2. **Add tests** for new features
3. **Update version** if applicable
4. **Describe changes** clearly in PR description
5. **Link issues** that the PR addresses

## Code Review

- Be respectful and constructive
- Focus on code quality and maintainability
- Test the changes locally
- Provide specific feedback

## Questions?

Open an issue or discussion on GitHub!

---

Thank you for contributing! 🎉

