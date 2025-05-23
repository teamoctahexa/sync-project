#!/bin/bash
#
# ==============================================================================
# File:               sync-project.sh
# Version:            1.1.1
# Description:        Universal sync tool for WordPress themes/plugins and web projects
# Author:             OctaHexa (https://octahexa.com)
# License:            GPLv2 or later
# ==============================================================================
#
# 🔧 USAGE:
#   ./sync-project.sh --dry-run   # Preview changes without syncing
#   ./sync-project.sh             # Sync files to server
#
# 📌 SETUP INSTRUCTIONS:
#   1. Copy this script to your project root folder.
#   2. Edit the SERVER DETAILS section with your credentials.
#   3. Make it executable: chmod +x sync-project.sh
#   4. Run the script to sync plugin/theme/custom code to your server.
#
# 🛡️ AUTHENTICATION METHODS:
#   ➤ Preferred: SSH key-based (no password prompt)
#     - ssh-keygen -t rsa -b 4096
#     - ssh-copy-id user@server
#
#   ➤ Optional: Password-based (uncomment and set PASSWORD)
#     - Requires sshpass package to be installed
#
# 💡 Works with:
#   - WordPress plugins and themes
#   - Web applications
#   - Custom PHP/JS/CSS projects
#

# === Dry Run Check ===
DRY_RUN=""
if [ "$1" = "--dry-run" ]; then
    DRY_RUN="--dry-run"
fi

# === SERVER DETAILS (edit below) ===

SERVER_IP="xxx.xxx.xxx.xxx"               # e.g. 192.168.1.100 or server.example.com
SERVER_USER="your-ssh-user"               # e.g. wp-admin, deploy
PROJECT_TYPE="plugin"                     # plugin, theme, or custom
DEST_DIR="/home/your-user/htdocs/example.com/wp-content"
CUSTOM_DEST_DIR=""                        # Only used if PROJECT_TYPE="custom"

# Optional (not recommended):
# PASSWORD="your-password"

# === Project Info ===
PROJECT_NAME=$(basename "$PWD")

if [ "$PROJECT_TYPE" = "plugin" ]; then
    TARGET_DIR="$DEST_DIR/plugins/$PROJECT_NAME"
    PROJECT_TYPE_DISPLAY="plugin"
elif [ "$PROJECT_TYPE" = "theme" ]; then
    TARGET_DIR="$DEST_DIR/themes/$PROJECT_NAME"
    PROJECT_TYPE_DISPLAY="theme"
elif [ "$PROJECT_TYPE" = "custom" ]; then
    TARGET_DIR="$CUSTOM_DEST_DIR"
    PROJECT_TYPE_DISPLAY="project"
else
    echo "❌ Invalid PROJECT_TYPE. Use 'plugin', 'theme', or 'custom'."
    exit 1
fi

# === Logging Info ===
echo "=================================================="
echo "🔄 Syncing $PROJECT_TYPE_DISPLAY: $PROJECT_NAME"
echo "=================================================="
echo "📂 Source:      $PWD"
echo "📁 Destination: $TARGET_DIR"
echo "🔐 Server:      $SERVER_USER@$SERVER_IP"

# === Clear Destination ===
if [ -z "$DRY_RUN" ]; then
    echo -e "\n🧹 Cleaning destination directory..."
    if [ -n "$PASSWORD" ]; then
        sshpass -p "$PASSWORD" ssh "$SERVER_USER@$SERVER_IP" "rm -rf '$TARGET_DIR'/*"
    else
        ssh "$SERVER_USER@$SERVER_IP" "rm -rf '$TARGET_DIR'/*"
    fi
fi

# === Exclusions ===
EXCLUSIONS=(
    "--exclude=.git/"
    "--exclude=.gitignore"
    "--exclude=docs/"
    "--exclude=*.zip"
    "--exclude=*.md"
    "--exclude=*.log"
    "--exclude=node_modules/"
    "--exclude=vendor/"
    "--exclude=tests/"
    "--exclude=sync-project.sh"
)

# === Sync Files ===
echo -e "\n🚀 Starting sync..."
if [ -n "$PASSWORD" ]; then
    sshpass -p "$PASSWORD" rsync -av --progress --itemize-changes "${EXCLUSIONS[@]}" $DRY_RUN . "$SERVER_USER@$SERVER_IP:$TARGET_DIR/"
else
    rsync -av --progress --itemize-changes "${EXCLUSIONS[@]}" $DRY_RUN . "$SERVER_USER@$SERVER_IP:$TARGET_DIR/"
fi

echo -e "\n✅ $PROJECT_TYPE_DISPLAY '$PROJECT_NAME' synced successfully!"
