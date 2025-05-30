# sync-project

A universal synchronization tool for WordPress themes/plugins and other web projects.

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

## 🔍 Overview

Sync-project is a lightweight bash script that simplifies the deployment process for WordPress themes, plugins, and custom web projects. It uses rsync to efficiently transfer only the changed files to your server, making deployments fast and reliable.

## ✨ Features

- **Universal compatibility**: Works with WordPress plugins, themes, and custom web projects
- **Efficient transfers**: Uses rsync to only transfer changed files
- **Dry run mode**: Preview changes before actual deployment
- **Secure**: Supports SSH key-based authentication (recommended)
- **Customizable**: Easily configure exclusions for files you don't want to sync
- **Simple setup**: Just copy the script to your project root and configure

## 🛠️ Requirements

- Bash shell environment
- SSH access to your server
- rsync installed on both local and remote systems
- Optional: sshpass (only if using password authentication, not recommended)

## 📋 Setup Instructions

1. Copy `sync-project.sh` to your project's root folder
2. Edit the SERVER DETAILS section in the script with your credentials:
   ```bash
   SERVER_IP="your-server-ip"               # e.g. 192.168.1.100 or server.example.com
   SERVER_USER="your-ssh-user"             # e.g. wp-admin, deploy
   PROJECT_TYPE="plugin"                   # plugin, theme, or custom
   DEST_DIR="/path/to/wordpress/wp-content" # Base WordPress content directory
   CUSTOM_DEST_DIR=""                      # Only used if PROJECT_TYPE="custom"
   ```
3. Make the script executable:
   ```bash
   chmod +x sync-project.sh
   ```

## 🔐 Authentication Methods

### Recommended: SSH Key-based Authentication

1. Generate an SSH key pair if you don't have one:
   ```bash
   ssh-keygen -t rsa -b 4096
   ```
2. Copy your public key to the server (use the site-user, not root):
   ```bash
   ssh-copy-id site-user@server
   ```
   
   > **Important:** Always use the site-user (the user who owns your web files) rather than root for SSH key exchange. This ensures proper ownership and permissions for your files when syncing. Using root can lead to permission issues that prevent your web application from functioning correctly.

### Alternative: Password Authentication (not recommended)

1. Install sshpass (if not already installed):
   ```bash
   # On macOS with Homebrew
   brew install hudochenkov/sshpass/sshpass
   
   # On Ubuntu/Debian
   sudo apt-get install sshpass
   ```
2. Uncomment and set the PASSWORD variable in the script

## 📝 Usage

### Preview Changes (Dry Run)

```bash
./sync-project.sh --dry-run
```

### Deploy to Server

```bash
./sync-project.sh
```

## 🔧 Customization

### Exclusions

The script includes common exclusions by default and also uses your project's .gitignore file to determine additional exclusions. You can modify the EXCLUSIONS array in the script to add or remove items:

```bash
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
```

> **Important:** Ensure your project has a .gitignore file in the root directory. The script automatically uses this file to make additional exclusions, preventing unnecessary files from being transferred to your server.

## 📚 Examples

### WordPress Plugin

```bash
# In your plugin directory
PROJECT_TYPE="plugin"
DEST_DIR="/home/user/public_html/wp-content"
```

### WordPress Theme

```bash
# In your theme directory
PROJECT_TYPE="theme"
DEST_DIR="/home/user/public_html/wp-content"
```

### Custom Web Project

```bash
# In your project directory
PROJECT_TYPE="custom"
CUSTOM_DEST_DIR="/home/user/public_html/custom-project"
```

## 📄 License

This project is licensed under the GPL v2 or later - see the [LICENSE](LICENSE) file for details.

## 👥 Author

Developed by [OctaHexa](https://octahexa.com)
