#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_DIR="/usr/local/share/zerobyte"
LOG_DIR="/usr/local/var/log/zerobyte"
DATA_DIR="$HOME/Library/Application Support/zerobyte"
PLIST_SRC="$SCRIPT_DIR/com.zerobyte.agent.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.zerobyte.agent.plist"

echo ""
echo "  Zerobyte macOS Installer"
echo "  ========================"
echo ""

# Check for required tools
if ! command -v bun &> /dev/null; then
    echo "Error: bun is not installed."
    echo "Install with: curl -fsSL https://bun.sh/install | bash"
    exit 1
fi

if ! command -v restic &> /dev/null; then
    echo "Warning: restic is not installed."
    echo "Install with: brew install restic"
fi

if ! command -v rclone &> /dev/null; then
    echo "Warning: rclone is not installed."
    echo "Install with: brew install rclone"
fi

# Check if dist exists
if [ ! -d "$PROJECT_ROOT/dist" ]; then
    echo "Error: dist directory not found."
    echo "Run 'bun run build' first."
    exit 1
fi

echo "Creating directories..."

# Create data directories
mkdir -p "$DATA_DIR/data"
mkdir -p "$DATA_DIR/repositories"
mkdir -p "$DATA_DIR/restic/cache"
mkdir -p "$DATA_DIR/volumes"

# Create log directory
sudo mkdir -p "$LOG_DIR"
sudo chown "$USER" "$LOG_DIR"

# Create install directory
sudo mkdir -p "$INSTALL_DIR"

echo "Installing application..."

# Copy application files
sudo cp -r "$PROJECT_ROOT/dist" "$INSTALL_DIR/"
sudo cp "$PROJECT_ROOT/package.json" "$INSTALL_DIR/"

# Install production dependencies
cd "$INSTALL_DIR"
sudo bun install --production --frozen-lockfile

# Set ownership
sudo chown -R "$USER" "$INSTALL_DIR"

echo "Installing launchd service..."

# Create LaunchAgents directory if needed
mkdir -p "$HOME/Library/LaunchAgents"

# Stop existing service if running
if launchctl list | grep -q "com.zerobyte.agent"; then
    echo "Stopping existing service..."
    launchctl unload "$PLIST_DST" 2>/dev/null || true
fi

# Install plist
cp "$PLIST_SRC" "$PLIST_DST"

echo ""
echo "  Installation complete!"
echo ""
echo "  Data location:    $DATA_DIR"
echo "  Install location: $INSTALL_DIR"
echo "  Log location:     $LOG_DIR"
echo ""
echo "  To start Zerobyte:"
echo "    launchctl load $PLIST_DST"
echo ""
echo "  To stop Zerobyte:"
echo "    launchctl unload $PLIST_DST"
echo ""
echo "  To view logs:"
echo "    tail -f $LOG_DIR/stdout.log"
echo ""
echo "  Web UI: http://localhost:4096"
echo ""
