#!/bin/bash

echo "Verifying Xcode project structure..."

# Check if project file exists and is valid
if [ ! -f "DropdownTerminal.xcodeproj/project.pbxproj" ]; then
    echo "❌ Project file not found"
    exit 1
fi

echo "✅ Project file exists"

# List targets and schemes
echo "📋 Available targets and schemes:"
xcodebuild -project DropdownTerminal.xcodeproj -list

# Check if source files exist
echo "📁 Checking source files..."
for file in "DropdownTerminal/AppDelegate.swift" "DropdownTerminal/MenuBarController.swift" "DropdownTerminal/SettingsManager.swift"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

# Try a syntax check build
echo "🔨 Attempting syntax check build..."
xcodebuild -project DropdownTerminal.xcodeproj \
           -target DropdownTerminal \
           -configuration Debug \
           -dry-run \
           DEVELOPMENT_TEAM="" \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO

if [ $? -eq 0 ]; then
    echo "✅ Project structure is valid for building"
else
    echo "❌ Build verification failed"
    exit 1
fi