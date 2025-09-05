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

# Check currently installed version
CURRENT_VERSION=""
CURRENT_COMMIT=""
CURRENT_TIMESTAMP=""
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    CURRENT_VERSION=$(defaults read "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
    CURRENT_COMMIT=$(defaults read "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info.plist" GitCommit 2>/dev/null || echo "unknown")
    CURRENT_TIMESTAMP=$(defaults read "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info.plist" BuildTimestamp 2>/dev/null || echo "unknown")
    
    if [ "$CURRENT_COMMIT" != "unknown" ] || [ "$CURRENT_TIMESTAMP" != "unknown" ]; then
        echo "📱 Currently installed:"
        if [ "$CURRENT_COMMIT" != "unknown" ]; then
            # Truncate commit to 8 characters
            CURRENT_COMMIT_SHORT=$(echo "$CURRENT_COMMIT" | cut -c1-8)
            echo "   Commit: $CURRENT_COMMIT_SHORT"
        fi
        if [ "$CURRENT_TIMESTAMP" != "unknown" ]; then
            echo "   Built: $CURRENT_TIMESTAMP"
        fi
    else
        echo "📱 DropdownTerminal is installed (build info unknown)"
    fi
else
    echo "📱 No existing installation found"
fi

# Get latest build info to compare with current installation
echo "🔍 Checking for latest successful build..."

# Get latest successful workflow run for the branch
WORKFLOWS_API="https://api.github.com/repos/${REPO}/actions/runs"

# Get workflow run ID from successful build
WORKFLOW_RUN=$(curl -fsSL "${WORKFLOWS_API}?branch=${BRANCH}&per_page=10" | \
  sed -n '/"conclusion": "success"/{ N; N; N; N; N; N; N; N; N; N; s/.*"id": \([0-9]*\).*/\1/p; }' | head -1)

# Fallback: try simpler parsing
if [ -z "$WORKFLOW_RUN" ]; then
  WORKFLOW_RUN=$(curl -fsSL "${WORKFLOWS_API}?branch=${BRANCH}&per_page=5" | \
    grep -B20 '"conclusion": "success"' | \
    grep '"id":' | head -1 | \
    sed 's/.*"id": \([0-9]*\).*/\1/')
fi

if [ -z "$WORKFLOW_RUN" ]; then
  echo "❌ No successful builds found for branch '$BRANCH'"
  echo "💡 Try: curl -fsSL https://raw.githubusercontent.com/${REPO}/dev/install.sh | sh -s main"
  exit 1
fi

echo "📦 Found build ID: $WORKFLOW_RUN"

# Get download URL for artifacts
ARTIFACTS_API="https://api.github.com/repos/${REPO}/actions/runs/${WORKFLOW_RUN}/artifacts"
DOWNLOAD_URL=$(curl -fsSL "$ARTIFACTS_API" | \
  sed -n 's/.*"archive_download_url": "\([^"]*\)".*/\1/p' | head -1)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ No artifacts found for this build"
  exit 1
fi

# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Check if we need to update by comparing with remote build
echo "🔍 Checking if update is needed..."

# For dev branch, check the dev-build release info
if [ "$BRANCH" = "dev" ]; then
  # Get release info for dev-build
  RELEASE_INFO=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/tags/dev-build" 2>/dev/null || echo "")
  if [ -n "$RELEASE_INFO" ]; then
    # Extract commit from release body or name
    REMOTE_COMMIT=$(echo "$RELEASE_INFO" | sed -n 's/.*"target_commitish": "\([^"]*\)".*/\1/p' | head -1)
    if [ -n "$REMOTE_COMMIT" ] && [ "$REMOTE_COMMIT" != "unknown" ]; then
      REMOTE_COMMIT_SHORT=$(echo "$REMOTE_COMMIT" | cut -c1-8)
      CURRENT_COMMIT_SHORT=$(echo "$CURRENT_COMMIT" | cut -c1-8)
      
      if [ "$CURRENT_COMMIT_SHORT" = "$REMOTE_COMMIT_SHORT" ] && [ "$CURRENT_COMMIT" != "unknown" ]; then
        echo "✅ Already up to date!"
        echo "   Current: $CURRENT_COMMIT_SHORT"
        echo "   Remote:  $REMOTE_COMMIT_SHORT"
        echo ""
        echo "🎯 Launch: open '$INSTALL_DIR/$APP_NAME.app'"
        exit 0
      fi
      
      echo "📋 Update available:"
      echo "   Current: $CURRENT_COMMIT_SHORT"
      echo "   Remote:  $REMOTE_COMMIT_SHORT"
    fi
  fi
fi

echo "⬇️  Downloading latest build..."
if [ "$BRANCH" = "dev" ]; then
  # For dev branch, use the fixed dev-build release
  echo "📦 Using dev-build release"
  DMG_URL="https://github.com/${REPO}/releases/download/dev-build/DropdownTerminal.dmg"
  
  if curl -fsSL "$DMG_URL" -o DropdownTerminal.dmg 2>/dev/null; then
    echo "✅ Downloaded from release"
  else
    echo "❌ Release not found, using artifacts fallback..."
    curl -fsSL -H "Accept: application/vnd.github.v3+json" "$DOWNLOAD_URL" -o artifact.zip
    unzip -q artifact.zip
    rm artifact.zip
  fi
else
  # For other branches, use artifacts
  curl -fsSL -H "Accept: application/vnd.github.v3+json" "$DOWNLOAD_URL" -o artifact.zip
  unzip -q artifact.zip
  rm artifact.zip
fi

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
# Show version info after installation
NEW_VERSION=$(defaults read "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
NEW_COMMIT=$(defaults read "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info.plist" GitCommit 2>/dev/null || echo "unknown")
NEW_TIMESTAMP=$(defaults read "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info.plist" BuildTimestamp 2>/dev/null || echo "unknown")

echo "✅ $APP_NAME installed successfully to $INSTALL_DIR!"

# Show detailed comparison
if [ "$CURRENT_COMMIT" != "unknown" ] || [ "$CURRENT_TIMESTAMP" != "unknown" ]; then
    if [ "$CURRENT_COMMIT" != "$NEW_COMMIT" ] || [ "$CURRENT_TIMESTAMP" != "$NEW_TIMESTAMP" ]; then
        echo "📈 Updated:"
        if [ "$CURRENT_COMMIT" != "unknown" ]; then
            echo "   From: $(echo "$CURRENT_COMMIT" | cut -c1-8)"
        fi
        if [ "$CURRENT_TIMESTAMP" != "unknown" ]; then
            echo "         $CURRENT_TIMESTAMP"
        fi
        if [ "$NEW_COMMIT" != "unknown" ]; then
            echo "   To:   $(echo "$NEW_COMMIT" | cut -c1-8)"
        fi
        if [ "$NEW_TIMESTAMP" != "unknown" ]; then
            echo "         $NEW_TIMESTAMP"
        fi
    else
        echo "🔄 Reinstalled same build"
    fi
else
    echo "🆕 Installed:"
    if [ "$NEW_COMMIT" != "unknown" ]; then
        echo "   Commit: $(echo "$NEW_COMMIT" | cut -c1-8)"
    fi
    if [ "$NEW_TIMESTAMP" != "unknown" ]; then
        echo "   Built: $NEW_TIMESTAMP"
    fi
fi
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