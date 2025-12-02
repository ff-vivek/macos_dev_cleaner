#!/bin/bash

# Installation script for AI File Cleaner

APP_NAME="AI File Cleaner"
APP_BUNDLE=".build/release/${APP_NAME}.app"
INSTALL_DIR="/Applications"

echo "🚀 AI File Cleaner - Installation Script"
echo ""

# Check if app bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ App bundle not found!"
    echo "   Please run ./build_app.sh first"
    exit 1
fi

echo "📱 Found app at: ${APP_BUNDLE}"
echo ""

# Check if app already installed
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    echo "⚠️  ${APP_NAME} is already installed in Applications"
    read -p "   Do you want to replace it? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

# Copy to Applications
echo "📦 Installing to ${INSTALL_DIR}..."
cp -r "${APP_BUNDLE}" "${INSTALL_DIR}/"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Installation successful!"
    echo ""
    echo "🎉 ${APP_NAME} has been installed to ${INSTALL_DIR}"
    echo ""
    echo "To launch the app:"
    echo "  • Open from Applications folder"
    echo "  • Or run: open -a '${APP_NAME}'"
    echo ""
else
    echo "❌ Installation failed!"
    echo "   You may need administrator privileges"
    echo "   Try: sudo ./install.sh"
    exit 1
fi




