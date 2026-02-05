#!/bin/bash

# Tab Switcher Native Host Installer

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_NAME="com.tabswitcher.native"
INSTALL_DIR="$HOME/.tab-switcher"
CHROME_NATIVE_HOSTS_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"

echo "========================================"
echo "Tab Switcher Native Host Installer"
echo "========================================"
echo ""

# Check if we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This installer only works on macOS"
    exit 1
fi

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed. Please install Xcode or Swift."
    exit 1
fi

# Get the extension ID
echo "To complete installation, you need your Chrome extension ID."
echo ""
echo "To find it:"
echo "  1. Open Chrome and go to: chrome://extensions"
echo "  2. Enable 'Developer mode' (toggle in top right)"
echo "  3. Find 'Tab Switcher'"
echo "  4. Copy the ID (a long string of letters)"
echo ""
read -p "Enter your extension ID: " EXTENSION_ID

if [[ -z "$EXTENSION_ID" ]]; then
    echo "Error: Extension ID is required"
    exit 1
fi

# Validate extension ID format (should be 32 lowercase letters)
if [[ ! "$EXTENSION_ID" =~ ^[a-z]{32}$ ]]; then
    echo "Warning: Extension ID format looks unusual. Proceeding anyway..."
fi

echo ""
echo "Step 1: Building native host..."
cd "$SCRIPT_DIR"
swift build -c release
echo "Build complete!"

echo ""
echo "Step 2: Installing binary..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/.build/release/tab-switcher" "$INSTALL_DIR/tab-switcher"
chmod +x "$INSTALL_DIR/tab-switcher"
echo "Binary installed to: $INSTALL_DIR/tab-switcher"

echo ""
echo "Step 3: Creating native messaging manifest..."
mkdir -p "$CHROME_NATIVE_HOSTS_DIR"

cat > "$CHROME_NATIVE_HOSTS_DIR/$HOST_NAME.json" << EOF
{
  "name": "$HOST_NAME",
  "description": "Tab Switcher Native Helper - Detects Ctrl+Tab for MRU tab switching",
  "path": "$INSTALL_DIR/tab-switcher",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/"]
}
EOF

echo "Manifest installed to: $CHROME_NATIVE_HOSTS_DIR/$HOST_NAME.json"

echo ""
echo "========================================"
echo "Installation complete!"
echo "========================================"
echo ""
echo "IMPORTANT: You must grant Accessibility permissions to the native host."
echo ""
echo "The first time you use Ctrl+Tab in Chrome, macOS will prompt you to"
echo "grant Accessibility permissions. If not, manually add it:"
echo ""
echo "  1. Open System Settings"
echo "  2. Go to: Privacy & Security > Accessibility"
echo "  3. Click the + button"
echo "  4. Add: $INSTALL_DIR/tab-switcher"
echo ""
echo "After granting permissions:"
echo "  1. Reload the extension in Chrome (chrome://extensions)"
echo "  2. Test with Ctrl+Tab in Chrome!"
echo ""
