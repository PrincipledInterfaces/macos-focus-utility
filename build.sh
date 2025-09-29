#!/bin/bash

# TOME macOS App Bundle Builder
# Builds a proper .app bundle with resources and entitlements

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_NAME="TOME"
BUNDLE_ID="com.tome.focusapp"
VERSION_FILE="VERSION"

get_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

echo -e "${PURPLE}🚀 Building TOME as macOS App Bundle${NC}"
echo ""

# Get version
VERSION=$(get_version)
BUILD_NUMBER=$(date +%Y%m%d%H%M)

echo -e "Version: ${GREEN}$VERSION${NC}"
echo -e "Build: ${YELLOW}$BUILD_NUMBER${NC}"
echo ""

# Clean previous builds
echo -e "${CYAN}🧹 Cleaning previous builds...${NC}"
rm -rf .build releases

# Create release directory
mkdir -p releases

# Build with Swift Package Manager
echo -e "${CYAN}🔨 Building Swift project...${NC}"
swift build --configuration release

# Get the built binary
BINARY_PATH=".build/release/$PROJECT_NAME"
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}❌ Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Swift build complete${NC}"

# Create app bundle structure
APP_DIR="releases/$PROJECT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo -e "${CYAN}📦 Creating app bundle structure...${NC}"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BINARY_PATH" "$MACOS_DIR/$PROJECT_NAME"
chmod +x "$MACOS_DIR/$PROJECT_NAME"

# Copy audio resources
if [ -d "Sources/TOME/Resources" ]; then
    echo -e "${CYAN}🎵 Copying audio resources...${NC}"
    cp -r Sources/TOME/Resources/* "$RESOURCES_DIR/"
    echo -e "${GREEN}✅ Audio files copied to app bundle${NC}"
else
    echo -e "${YELLOW}⚠️  No audio resources found${NC}"
fi

# Copy OpenAI API key if it exists
if [ -f "openai_key.txt" ]; then
    echo -e "${CYAN}🔑 Copying OpenAI API key...${NC}"
    cp "openai_key.txt" "$RESOURCES_DIR/"
    echo -e "${GREEN}✅ OpenAI API key copied to app bundle${NC}"
else
    echo -e "${YELLOW}⚠️  No OpenAI API key found${NC}"
fi

# Copy icon if available
if [ -f "icon.png" ]; then
    cp "icon.png" "$RESOURCES_DIR/AppIcon.png"
    echo -e "${GREEN}✅ App icon copied${NC}"
fi

# Create Info.plist
echo -e "${CYAN}📝 Creating Info.plist...${NC}"
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSCalendarsUsageDescription</key>
    <string>TOME needs calendar access to monitor upcoming meetings and events for intelligent notification filtering.</string>
    <key>NSContactsUsageDescription</key>
    <string>TOME needs contacts access to identify important people for notification filtering.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>TOME needs AppleScript access to monitor and control applications for focus management.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>TOME may use audio features for focus enhancement.</string>
</dict>
</plist>
EOF

# Create entitlements file for proper permissions
echo -e "${CYAN}🔐 Creating entitlements...${NC}"
cat > "$CONTENTS_DIR/entitlements.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
EOF

# Sign the app (development signing)
echo -e "${CYAN}✍️  Signing app bundle...${NC}"
codesign --force --deep --sign - --entitlements "$CONTENTS_DIR/entitlements.plist" "$APP_DIR" || {
    echo -e "${YELLOW}⚠️  Code signing failed (this is okay for development)${NC}"
}

# Verify the bundle
echo -e "${CYAN}🔍 Verifying app bundle...${NC}"
if [ -f "$MACOS_DIR/$PROJECT_NAME" ] && [ -f "$CONTENTS_DIR/Info.plist" ]; then
    echo -e "${GREEN}✅ App bundle verification passed${NC}"
else
    echo -e "${RED}❌ App bundle verification failed${NC}"
    exit 1
fi

# Success!
echo ""
echo -e "${GREEN}🎉 TOME.app created successfully!${NC}"
echo ""
echo -e "${CYAN}📍 Location:${NC} releases/TOME.app"
echo -e "${CYAN}📦 Size:${NC} $(du -sh releases/TOME.app | cut -f1)"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Install: cp -r releases/TOME.app /Applications/"
echo "2. Launch: open /Applications/TOME.app"
echo "3. Or run directly: open releases/TOME.app"
echo ""
echo -e "${CYAN}🔧 Development:${NC}"
echo "• Run from terminal: releases/TOME.app/Contents/MacOS/TOME"
echo "• View logs: Console.app → User Reports → TOME"
echo ""

# List bundle contents for verification
echo -e "${BLUE}📂 Bundle contents:${NC}"
find "$APP_DIR" -type f | sed 's|^releases/TOME.app/|  |' | head -20
if [ $(find "$APP_DIR" -type f | wc -l) -gt 20 ]; then
    echo "  ... and $(( $(find "$APP_DIR" -type f | wc -l) - 20 )) more files"
fi
echo ""