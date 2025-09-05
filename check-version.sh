#!/bin/bash

echo "🔍 Checking DropdownTerminal version..."
echo ""

APP_PATH="/Applications/DropdownTerminal.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ DropdownTerminal.app not found in Applications"
    exit 1
fi

echo "📁 App bundle info:"
ls -la "$APP_PATH/Contents/MacOS/DropdownTerminal"
echo ""

echo "📝 Build info file:"
if [ -f "$APP_PATH/Contents/Resources/build-info.txt" ]; then
    cat "$APP_PATH/Contents/Resources/build-info.txt"
else
    echo "❌ build-info.txt not found (old version?)"
fi
echo ""

echo "📋 Info.plist version:"
if /usr/libexec/PlistBuddy -c "Print GitCommit" "$APP_PATH/Contents/Info.plist" 2>/dev/null; then
    echo "Git commit found in plist"
else
    echo "❌ No GitCommit in Info.plist (old version?)"
fi

echo ""
echo "🕒 App bundle timestamp:"
stat -f "Modified: %Sm" "$APP_PATH/Contents/MacOS/DropdownTerminal"