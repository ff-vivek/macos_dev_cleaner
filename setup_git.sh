#!/bin/bash

# Git Repository Setup Script
# Prepares FileCleanerAI for public GitHub repository

set -e

echo "🚀 Preparing FileCleanerAI for Git..."
echo ""

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "📦 Initializing Git repository..."
    git init
    echo "✓ Git repository initialized"
else
    echo "✓ Git repository already initialized"
fi

# Check git status
echo ""
echo "📋 Current Git Status:"
git status --short

# Add all files
echo ""
echo "➕ Staging files..."
git add .

# Show what will be committed
echo ""
echo "📝 Files to be committed:"
git status --short

echo ""
echo "✅ Repository prepared!"
echo ""
echo "Next steps:"
echo "  1. Review the staged files above"
echo "  2. Commit: git commit -m \"Initial commit: AI File Cleaner v1.0.0\""
echo "  3. Create GitHub repo: https://github.com/new"
echo "  4. Add remote: git remote add origin https://github.com/YOUR_USERNAME/FileCleanerAI.git"
echo "  5. Push: git push -u origin main"
echo ""
echo "📚 Documentation files:"
echo "  - README.md (project overview)"
echo "  - LICENSE (MIT)"
echo "  - CONTRIBUTING.md (contribution guidelines)"
echo "  - CHANGELOG.md (version history)"
echo ""

