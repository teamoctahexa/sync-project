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
# Usage:
#   ./sync-project.sh --dry-run   # Preview changes without syncing
#   ./sync-project.sh             # Sync files to server
#
# Features:
#   - Works with WordPress themes, plugins, or any web project
#   - Deletes all files in destination before sync (clean sync)
#   - Syncs only changed files using rsync (efficient)
#   - Excludes unnecessary files and directories
#   - Shows detailed progress and changes
#
# SSH Authentication:
#   This script supports two authentication methods:
#
#   1. SSH Key Authentication (Recommended):
#      - Generate keys: ssh-keygen -t rsa -b 4096
#      - Copy to server: ssh-copy-id user@server
#      - No password needed after setup
#
#   2. Password Authentication:
#      - Edit the SERVER_DETAILS section below
#      - Add your password (less secure)
#      - Or enter password when prompted
#
# Setup Instructions:
#   1. Copy this script to the ROOT of your project directory (same level as your main files)
#   2. Edit the SERVER_DETAILS section below with your credentials
#   3. Make executable: chmod +x sync-project.sh
#   4. Run: ./sync-project.sh
#
# SECURITY NOTES:
#   - This script is automatically excluded from syncing to protect your credentials
#   - Add to .gitignore to prevent committing credentials to your repository
#   - For shared projects, each developer should maintain their own copy locally
#
# Compatible with:
#   - WordPress themes/plugins
#   - Windsurf projects
#   - Any web development project
#

# Check for dry-run flag
DRY_RUN=""
if [ "$1" = "--dry-run" ]; then
    DRY_RUN="--dry-run"
fi

# ========================================
# SERVER_DETAILS - Edit these settings
# ========================================

# Server connection details
SERVER_IP="xxx.xxx.xxx.xxx"          # Server IP or hostname
SERVER_USER="your-ssh-user"    # SSH username

# Project destination details
PROJECT_TYPE="plugin"              # Options: plugin, theme, custom
DEST_DIR="/home/your-user/htdocs/example.com/wp-content"

# For custom projects, set the full destination path
CUSTOM_DEST_DIR=""                # Only used if PROJECT_TYPE="custom"

# Optional: Password (less secure, prefer SSH keys)
# PASSWORD="your-password"        # Uncomment and set if needed

# Get current directory name
PROJECT_NAME=$(basename "$PWD")

# Determine destination directory based on project type
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
    echo "Error: Invalid PROJECT_TYPE. Use 'plugin', 'theme', or 'custom'."
    exit 1
fi

# Show what we're doing
echo "=================================================="
echo "Syncing $PROJECT_TYPE_DISPLAY: $PROJECT_NAME"
echo "=================================================="
echo "Source: $PWD"
echo "Destination: $TARGET_DIR"
echo "Server: $SERVER_USER@$SERVER_IP"

# First delete everything in destination (unless dry-run)
if [ "$DRY_RUN" = "" ]; then
    echo -e "\nDeleting files from destination..."
    if [ -n "$PASSWORD" ]; then
        # Use sshpass if password is provided
        sshpass -p "$PASSWORD" ssh $SERVER_USER@$SERVER_IP "rm -rf $TARGET_DIR/*"
        
        # Also explicitly delete any .DS_Store files that might be hidden
        echo "Deleting .DS_Store files from server..."
        sshpass -p "$PASSWORD" ssh $SERVER_USER@$SERVER_IP "find $TARGET_DIR -name '.DS_Store' -type f -delete"
        echo "Deleting docs directory from server..."
        sshpass -p "$PASSWORD" ssh $SERVER_USER@$SERVER_IP "rm -rf $TARGET_DIR/docs"
    else
        # Use SSH key authentication
        ssh $SERVER_USER@$SERVER_IP "rm -rf $TARGET_DIR/*"
        
        # Also explicitly delete any .DS_Store files that might be hidden
        echo "Deleting .DS_Store files from server..."
        ssh $SERVER_USER@$SERVER_IP "find $TARGET_DIR -name '.DS_Store' -type f -delete"
        echo "Deleting docs directory from server..."
        ssh $SERVER_USER@$SERVER_IP "rm -rf $TARGET_DIR/docs"
    fi
fi

# Define exclusions - using pattern format that works with rsync
EXCLUSIONS=(
    "--exclude=.git"
    "--exclude=.gitignore"
    "--exclude=docs"
    "--exclude=*.zip"
    "--exclude=*.md"
    "--exclude=*.log"
    "--exclude=node_modules"
    "--exclude=vendor"
    "--exclude=tests"
    "--exclude=sync-project.sh"
    "--exclude=sync-plugin.sh"
    "--exclude=.DS_Store"
    "--exclude=.AppleDouble"
    "--exclude=.LSOverride"
    "--exclude=Icon\r\r"
    "--exclude=._*"
    "--exclude=.DocumentRevisions-V100"
    "--exclude=.fseventsd"
    "--exclude=.Spotlight-V100"
    "--exclude=.TemporaryItems"
    "--exclude=.Trashes"
    "--exclude=.VolumeIcon.icns"
    "--exclude=.com.apple.timemachine.donotpresent"
    "--exclude=.AppleDB"
    "--exclude=.AppleDesktop"
    "--exclude='Network Trash Folder'"
    "--exclude='Temporary Items'"
    "--exclude=.apdisk"
)

# Sync only changed files using rsync
echo -e "\nSyncing files..."
if [ -n "$PASSWORD" ]; then
    # Use sshpass if password is provided
    sshpass -p "$PASSWORD" rsync -av --delete --progress --itemize-changes ${EXCLUSIONS[@]} $DRY_RUN \
        --filter="- .DS_Store" \
        --filter="- ._*" \
        --filter="- docs/***" \
        --filter="- sync-project.sh" \
        . $SERVER_USER@$SERVER_IP:$TARGET_DIR/
else
    # Use SSH key authentication
    rsync -av --delete --progress --itemize-changes ${EXCLUSIONS[@]} $DRY_RUN \
        --filter="- .DS_Store" \
        --filter="- ._*" \
        --filter="- docs/***" \
        --filter="- sync-project.sh" \
        . $SERVER_USER@$SERVER_IP:$TARGET_DIR/
fi

# Show success message
echo -e "\n$PROJECT_TYPE_DISPLAY '$PROJECT_NAME' synced successfully!"
