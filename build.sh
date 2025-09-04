#!/bin/bash

set -e

echo "Building DropdownTerminal..."

# Clean any previous builds
rm -rf build/
rm -rf DropdownTerminal.xcarchive
rm -f DropdownTerminal.dmg

# Build the project
xcodebuild -project DropdownTerminal.xcodeproj \
           -scheme DropdownTerminal \
           -configuration Release \
           -archivePath DropdownTerminal.xcarchive \
           archive

echo "Exporting application..."

# Export the archive
xcodebuild -exportArchive \
           -archivePath DropdownTerminal.xcarchive \
           -exportOptionsPlist exportOptions.plist \
           -exportPath ./build

echo "Creating DMG..."

# Create DMG
mkdir -p dmg
cp -R build/DropdownTerminal.app dmg/
hdiutil create -volname "DropdownTerminal" -srcfolder dmg -ov -format UDZO DropdownTerminal.dmg

# Clean up
rm -rf dmg/
rm -rf DropdownTerminal.xcarchive

echo "Build complete! DropdownTerminal.dmg is ready for distribution."
echo "Application binary is available at: build/DropdownTerminal.app"