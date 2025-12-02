#!/bin/bash

# Enhanced Build Script for FileCleanerAI macOS App
# Supports debug, release, and distribution builds

set -e  # Exit on error

# Configuration
APP_NAME="AI File Cleaner"
BUNDLE_ID="com.filecleaner.ai"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="15.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  🚀 FileCleanerAI Build Script v1.0              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}➜${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

# Parse arguments
BUILD_CONFIG="release"
CLEAN=false
OPEN_APP=false
CREATE_DMG=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            BUILD_CONFIG="debug"
            shift
            ;;
        -r|--release)
            BUILD_CONFIG="release"
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -o|--open)
            OPEN_APP=true
            shift
            ;;
        --dmg)
            CREATE_DMG=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -d, --debug      Build in debug mode (default: release)"
            echo "  -r, --release    Build in release mode"
            echo "  -c, --clean      Clean before building"
            echo "  -o, --open       Open app after building"
            echo "  --dmg            Create DMG installer"
            echo "  -v, --verbose    Verbose output"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Start build
print_header
print_step "Build Configuration: $BUILD_CONFIG"
echo ""

# Set build directory
BUILD_DIR=".build/${BUILD_CONFIG}"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# Clean if requested
if [ "$CLEAN" = true ]; then
    print_step "Cleaning previous builds..."
    rm -rf ".build"
    print_success "Clean complete"
    echo ""
fi

# Build executable
print_step "Compiling Swift code..."
if [ "$VERBOSE" = true ]; then
    swift build -c ${BUILD_CONFIG}
else
    swift build -c ${BUILD_CONFIG} 2>&1 | grep -E "(warning:|error:|Build complete)" || true
fi

if [ $? -ne 0 ]; then
    print_error "Build failed!"
    exit 1
fi

print_success "Build complete"
echo ""

# Create app bundle
print_step "Creating app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/FileCleanerAI" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy and configure Info.plist
cp "FileCleanerAI/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable '${APP_NAME}'" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier '${BUNDLE_ID}'" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString '${VERSION}'" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion '${BUILD_NUMBER}'" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion '${MIN_MACOS}'" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true

print_success "App bundle created"
echo ""

# Check for code signing
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    print_step "Code signing certificate found..."
    print_warning "Code signing not implemented yet. Run manually if needed:"
    echo "    codesign --deep --force --verify --verbose --sign \"Developer ID Application\" \"${APP_BUNDLE}\""
else
    print_warning "No code signing certificate found"
    print_warning "App will run locally but cannot be distributed"
fi
echo ""

# Create DMG if requested
if [ "$CREATE_DMG" = true ]; then
    print_step "Creating DMG installer..."
    DMG_NAME="${APP_NAME}-${VERSION}.dmg"
    DMG_PATH=".build/${DMG_NAME}"
    
    # Remove old DMG if exists
    [ -f "$DMG_PATH" ] && rm "$DMG_PATH"
    
    # Create DMG
    hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_BUNDLE}" -ov -format UDZO "$DMG_PATH"
    
    if [ $? -eq 0 ]; then
        print_success "DMG created: $DMG_PATH"
    else
        print_error "DMG creation failed"
    fi
    echo ""
fi

# Print summary
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
print_success "Build successful!"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📱 App Bundle:"
echo "   ${APP_BUNDLE}"
echo ""
echo "📦 Size:"
du -sh "${APP_BUNDLE}" | awk '{print "   " $1}'
echo ""
echo "ℹ️  Info:"
echo "   Name:    ${APP_NAME}"
echo "   Version: ${VERSION} (${BUILD_NUMBER})"
echo "   Bundle:  ${BUNDLE_ID}"
echo "   Min OS:  macOS ${MIN_MACOS}"
echo ""

if [ "$CREATE_DMG" = true ]; then
    echo "💿 DMG Installer:"
    echo "   ${DMG_PATH}"
    echo ""
fi

echo "🚀 To run:"
echo "   open '${APP_BUNDLE}'"
echo ""
echo "📥 To install:"
echo "   cp -r '${APP_BUNDLE}' /Applications/"
echo ""

if [ "$BUILD_CONFIG" = "release" ]; then
    echo "📦 To distribute:"
    echo "   1. Sign: codesign --deep --force --sign \"Developer ID\" \"${APP_BUNDLE}\""
    echo "   2. Notarize: xcrun notarytool submit \"${APP_BUNDLE}\" --wait"
    echo "   3. Staple: xcrun stapler staple \"${APP_BUNDLE}\""
    echo ""
fi

# Open app if requested
if [ "$OPEN_APP" = true ]; then
    print_step "Opening app..."
    killall "${APP_NAME}" 2>/dev/null || true
    sleep 1
    open "${APP_BUNDLE}"
fi

print_success "Done!"
