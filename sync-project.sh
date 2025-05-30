#!/bin/bash
#
# ==============================================================================
# File:               sync-project.sh
# Version:            1.2.1
# Description:        Universal sync tool for WordPress themes/plugins with backup system
# Author:             OctaHexa (https://octahexa.com)
# GitHub:             https://github.com/teamoctahexa/sync-project
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
#      - Copy to server: ssh-copy-id site-user@server (use site-user, NOT root)
#      - IMPORTANT: Always use the site-user who owns the web files to avoid permission issues
#      - No password needed after setup
#
#   2. Password Authentication:
#      - Edit the SERVER_DETAILS section below
#      - Add your password (less secure)
#      - Or enter password when prompted
#
# Setup Instructions:
#   1. Copy this script to the ROOT of your project directory (same level as your main files)
#   2. Ensure you have a .gitignore file in your project root (the script uses it for additional exclusions)
#   3. Edit the SERVER_DETAILS section below with your credentials
#   4. Make executable: chmod +x sync-project.sh
#   5. Run: ./sync-project.sh
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

# ========================================
# SERVER_DETAILS - Edit these settings
# ========================================

# Server connection details
SERVER_IP="xxx.xxx.xxx.xxx"          # Server IP or hostname
SERVER_USER="site-user"              # SSH username of the site-user (usually not root)

# Project destination details
PROJECT_TYPE="plugin"              # Options: plugin, theme, custom
DEST_DIR="/home/site-user/htdocs/example.com/wp-content"

# For custom projects, set the full destination path
CUSTOM_DEST_DIR=""                # Only used if PROJECT_TYPE="custom"

# Optional: Password (less secure, prefer SSH keys)
# PASSWORD="your-password"        # Uncomment and set if needed

# ========================================
# Backup Configuration - Edit these settings
# ========================================

# Set to true to automatically create backups before syncing
# Can be overridden with --no-backup command line flag
CREATE_BACKUP=false

# Where to store backups
BACKUP_DIR="/Users/brian/Documents/GitHub/_plugin-backups"

# How many backups to keep per version (set to 0 to keep all)
MAX_BACKUPS_PER_VERSION=5

# How many days to keep backups (set to 0 to keep indefinitely)
MAX_BACKUP_AGE_DAYS=30

# Files/directories to exclude from backups (space-separated list)
BACKUP_EXCLUDES=("*.git*" "*/.git/*" "node_modules/*" "backups/*" "vendor/*" "*.zip" "*.log" "tests/")

# ========================================
# Command line argument processing
# ========================================

DRY_RUN=""  # Default: perform actual sync

# Process command line arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        --no-backup)
            CREATE_BACKUP=false
            ;;
        --help)
            echo "Usage: ./sync-project.sh [options]"
            echo "Options:"
            echo "  --dry-run     Preview changes without syncing"
            echo "  --no-backup   Skip backup creation before syncing"
            echo "  --help        Show this help message"
            exit 0
            ;;
    esac
done

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

# ========================================
# Display Information
# ========================================

# Show what we're doing
echo "=================================================="
echo "Syncing $PROJECT_TYPE_DISPLAY: $PROJECT_NAME"
echo "=================================================="
echo "Source: $PWD"
echo "Destination: $TARGET_DIR"
echo "Server: $SERVER_USER@$SERVER_IP"
echo "Backup: $(if [ "$CREATE_BACKUP" = true ]; then echo "Enabled"; else echo "Disabled"; fi)"

# ========================================
# Backup Creation Function
# ========================================

create_backup() {
    # Parameters
    local plugin_slug=$1
    local backup_dir=$2
    local max_per_version=$3
    local max_days=$4
    local excludes=(${@:5})
    
    echo -e "\n=================================================="
    echo "Creating backup of $plugin_slug"
    echo "=================================================="
    
    # Extract plugin version from main file
    local version=$(grep "Version:" "${plugin_slug}.php" | awk -F': ' '{print $2}' | tr -d '\r')
    
    # Generate readable date format
    local date_str=$(date "+%Y-%m-%d")
    local time_str=$(date "+%H.%M.%S")
    
    # Clean up version string (remove any spaces)
    local clean_version=$(echo "$version" | tr -d " \t\n\r")
    
    # Set backup filename with human-readable format (no spaces)
    local backup_file="$backup_dir/${plugin_slug}_v${clean_version}_${date_str}_${time_str}.zip"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    # Build exclude parameters for zip command
    local exclude_params=""
    for excl in "${excludes[@]}"; do
        exclude_params="$exclude_params -x \"$excl\""
    done
    
    # Create backup
    echo "Creating backup file: $(basename "$backup_file")"
    eval "zip -r \"$backup_file\" . $exclude_params"
    
    # Check if backup succeeded
    if [ $? -ne 0 ]; then
        echo "\n⚠️ Backup creation failed!"
        return 1
    fi
    
    echo "\n✅ Backup created successfully!"
    echo "📁 Location: $backup_file"
    echo "📋 Version: $version"
    echo "📊 Size: $(du -h "$backup_file" | cut -f1)"
    
    # Perform backup rotation if enabled
    if [ $max_per_version -gt 0 ] || [ $max_days -gt 0 ]; then
        echo "\n🔄 Performing backup rotation..."
        
        # Remove old backups by count (keep only the most recent N per version)
        if [ $max_per_version -gt 0 ]; then
            echo "  - Keeping $max_per_version backups per version"
            # For each version, get a list of backup files sorted by date (oldest first)
            for ver in $(find "$backup_dir" -name "${plugin_slug}_v*" -type f | grep -o "${plugin_slug}_v[0-9]*\.[0-9]*\.[0-9]*" | sort | uniq); do
                # Extract just the version number for finding files
                local version_num=$(echo "$ver" | sed "s/${plugin_slug}_v//g")
                local count=$(find "$backup_dir" -name "${plugin_slug}_v${version_num}_*" | wc -l)
                if [ $count -gt $max_per_version ]; then
                    # Calculate how many to remove
                    local remove_count=$((count - max_per_version))
                    echo "    - Found $count backups for version $version_num, removing $remove_count oldest"
                    # List files by modification time, oldest first, and remove the oldest ones
                    find "$backup_dir" -name "${plugin_slug}_v${version_num}_*" -type f -print0 | xargs -0 ls -tr | head -n $remove_count | xargs rm -f
                fi
            done
        fi
        
        # Remove backups older than MAX_BACKUP_AGE_DAYS
        if [ $max_days -gt 0 ]; then
            echo "  - Removing backups older than $max_days days"
            find "$backup_dir" -name "${plugin_slug}-*" -type f -mtime +$max_days -delete -print | while read file; do
                echo "    - Removed old backup: $(basename "$file")"
            done
        fi
    fi
    
    return 0
}

# Create backup before syncing (if enabled)
if [ "$CREATE_BACKUP" = true ]; then
    create_backup "$PROJECT_NAME" "$BACKUP_DIR" $MAX_BACKUPS_PER_VERSION $MAX_BACKUP_AGE_DAYS "${BACKUP_EXCLUDES[@]}"
    if [ $? -ne 0 ]; then
        echo "\n⚠️ Warning: Backup failed, but continuing with sync..."
    fi
fi

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
# Default exclusions plus integration with project's .gitignore file
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
    "--exclude-from=.gitignore"  # Uses your project's .gitignore for additional exclusions
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

# First, let's clean up any ~ directories that might have been created
find . -name "~" -type d -exec rm -rf {} \; 2>/dev/null || true

if [ -n "$PASSWORD" ]; then
    # Use sshpass if password is provided
    sshpass -p "$PASSWORD" rsync -av --delete --progress --itemize-changes ${EXCLUSIONS[@]} $DRY_RUN \
        --filter="- .DS_Store" \
        --filter="- ._*" \
        --filter="- docs/***" \
        --filter="- sync-project.sh" \
        --filter="- sync-plugin.sh" \
        --partial --ignore-errors \
        . $SERVER_USER@$SERVER_IP:$TARGET_DIR/
    
    # Check the exit code, but exit code 23 is acceptable
    RSYNC_EXIT=$?
    if [ $RSYNC_EXIT -ne 0 ] && [ $RSYNC_EXIT -ne 23 ]; then
        echo -e "\n⚠️ Error: rsync failed with exit code $RSYNC_EXIT"
        exit $RSYNC_EXIT
    elif [ $RSYNC_EXIT -eq 23 ]; then
        echo -e "\n⚠️ Notice: Some files were not transferred (code 23), but this is typically non-critical"
    fi
else
    # Use SSH key authentication
    rsync -av --delete --progress --itemize-changes ${EXCLUSIONS[@]} $DRY_RUN \
        --filter="- .DS_Store" \
        --filter="- ._*" \
        --filter="- docs/***" \
        --filter="- sync-project.sh" \
        --filter="- sync-plugin.sh" \
        --partial --ignore-errors \
        . $SERVER_USER@$SERVER_IP:$TARGET_DIR/
    
    # Check the exit code, but exit code 23 is acceptable
    RSYNC_EXIT=$?
    if [ $RSYNC_EXIT -ne 0 ] && [ $RSYNC_EXIT -ne 23 ]; then
        echo -e "\n⚠️ Error: rsync failed with exit code $RSYNC_EXIT"
        exit $RSYNC_EXIT
    elif [ $RSYNC_EXIT -eq 23 ]; then
        echo -e "\n⚠️ Notice: Some files were not transferred (code 23), but this is typically non-critical"
    fi
fi

# Show success message
echo -e "\n$PROJECT_TYPE_DISPLAY '$PROJECT_NAME' synced successfully!"
