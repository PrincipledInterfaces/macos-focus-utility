#!/bin/bash

echo "🎬 TOME - Marketing Export Debug Mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Enable debug mode if not already enabled
if [ ! -f "Sources/TOME/MarketingExporter.swift" ]; then
    echo "🔧 Enabling debug mode..."
    ./MarketingExport/Scripts/enable-export-debug.sh
    echo ""
fi

# Build and run with sudo
echo "🔨 Building TOME with debug features..."
echo ""
sudo ./build.sh

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✨ TOME launched in debug mode!"
    echo ""
    echo "🎯 Debug Controls (top-right corner):"
    echo "   • Export button - Exports all marketing assets"
    echo "   • Quit button - Closes the app"
    echo ""
    echo "📁 Assets will be exported to:"
    echo "   ./MarketingExport/"
    echo ""
    echo "💡 After exporting, convert animations to MOV:"
    echo "   cd MarketingExport/Scripts && ./convert-to-mov.sh"
    echo ""
    echo "🗑️  To disable debug mode and restore normal app:"
    echo "   ./MarketingExport/Scripts/disable-export-debug.sh"
    echo ""
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi
