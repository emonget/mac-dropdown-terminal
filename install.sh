#!/bin/bash

# DropdownTerminal Remote Installer
# curl -fsSL https://raw.githubusercontent.com/emonget/mac-dropdown-terminal/dev/install.sh | sh

set -e

REPO="emonget/mac-dropdown-terminal"
INSTALL_DIR="/Applications"
APP_NAME="DropdownTerminal"
BRANCH="${1:-dev}"

echo "🚀 DropdownTerminal Installer"
echo "📍 Installing from branch: $BRANCH"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "❌ This installer is for macOS only"
  exit 1
fi

# Check for required tools
command -v curl >/dev/null 2>&1 || { echo "❌ curl is required but not installed"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "❌ unzip is required but not installed"; exit 1; }

echo "🔍 Checking for latest successful build..."

# Get latest successful workflow run for the branch
WORKFLOWS_API="https://api.github.com/repos/${REPO}/actions/runs"
WORKFLOW_DATA=$(curl -fsSL "${WORKFLOWS_API}?branch=${BRANCH}&status=success&per_page=5")
WORKFLOW_RUN=$(echo "$WORKFLOW_DATA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

if [ -z "$WORKFLOW_RUN" ]; then
  echo "❌ No successful builds found for branch '$BRANCH'"
  echo "💡 Try: curl -fsSL https://raw.githubusercontent.com/${REPO}/dev/install.sh | sh -s main"
  exit 1
fi

echo "📦 Found build ID: $WORKFLOW_RUN"

# Get download URL for artifacts
ARTIFACTS_API="https://api.github.com/repos/${REPO}/actions/runs/${WORKFLOW_RUN}/artifacts"
DOWNLOAD_URL=$(curl -fsSL "$ARTIFACTS_API" | \
  grep -o '"archive_download_url":"[^"]*' | cut -d'"' -f4 | head -1)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ No artifacts found for this build"
  exit 1
fi

# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

echo "⬇️  Downloading latest build..."
curl -fsSL -H "Accept: application/vnd.github.v3+json" "$DOWNLOAD_URL" -o artifact.zip

echo "📂 Extracting..."
unzip -q artifact.zip
rm artifact.zip

echo "🛑 Stopping existing app..."
pkill -f "$APP_NAME" 2>/dev/null || true

echo "🗑️  Removing old version..."
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"

echo "📱 Installing new version..."

# Install from DMG if available, otherwise direct app
if [ -f "${APP_NAME}.dmg" ]; then
  echo "   Mounting DMG..."
  MOUNT_POINT=$(hdiutil attach "${APP_NAME}.dmg" -nobrowse | grep -o '/Volumes/[^[:space:]]*')
  cp -R "${MOUNT_POINT}/${APP_NAME}.app" "$INSTALL_DIR/"
  hdiutil detach "$MOUNT_POINT" -quiet
elif [ -d "${APP_NAME}.app" ]; then
  cp -R "${APP_NAME}.app" "$INSTALL_DIR/"
else
  echo "❌ No installable app found in artifacts"
  cd /
  rm -rf "$TMP_DIR"
  exit 1
fi

# Cleanup
cd /
rm -rf "$TMP_DIR"

echo ""
echo "✅ $APP_NAME installed successfully to $INSTALL_DIR!"
echo ""
echo "🚨 Important: Grant accessibility permissions when prompted"
echo "   System Preferences → Security & Privacy → Privacy → Accessibility"
echo ""
echo "🎯 Launch: open '$INSTALL_DIR/$APP_NAME.app'"
echo "   Or find it in Applications folder"
echo ""

# Offer to launch
if [ -t 0 ]; then  # Only prompt if running interactively
  echo -n "Launch now? (y/N): "
  read -r launch
  if [[ "$launch" =~ ^[Yy]$ ]]; then
    open "$INSTALL_DIR/$APP_NAME.app"
  fi
fi