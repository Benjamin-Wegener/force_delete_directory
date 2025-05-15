#!/bin/bash

# Force Delete Directory Script
# This script forcefully deletes a directory and all its contents
# Handles permissions, running processes, and mounts

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges to handle all permissions."
    echo "Please run with sudo: sudo $0 <directory_path>"
    exit 1
fi

# Check if directory path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory_path>"
    echo "Please provide the full path to the directory you want to delete."
    exit 1
fi

TARGET_DIR="$1"

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

echo "WARNING: This script will forcefully delete '$TARGET_DIR' and ALL its contents."
echo "This action cannot be undone. Are you sure you want to continue? (y/N)"
read -r confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation canceled."
    exit 0
fi

echo "Starting forced deletion of '$TARGET_DIR'..."

# Function to find and stop processes using the directory
kill_processes() {
    local dir="$1"
    echo "Finding and killing processes using '$dir'..."
    
    # Find processes using files in the directory
    lsof +D "$dir" 2>/dev/null | awk '{if (NR>1) print $2}' | sort -u | while read -r pid; do
        if [ -n "$pid" ]; then
            echo "Killing process $pid ($(ps -p "$pid" -o comm= 2>/dev/null))"
            kill -9 "$pid" 2>/dev/null
        fi
    done
}

# Function to unmount any filesystems mounted within the target directory
unmount_filesystems() {
    local dir="$1"
    echo "Checking for and unmounting filesystems under '$dir'..."
    
    # Find all mount points under the directory
    mount | grep -E "on $dir(/|\s)" | awk '{print $3}' | sort -r | while read -r mount_point; do
        echo "Unmounting $mount_point"
        umount -f "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null
        
        # Check if unmount was successful
        if mountpoint -q "$mount_point"; then
            echo "Warning: Could not unmount $mount_point. Trying lazy unmount..."
            umount -l "$mount_point"
        fi
    done
}

# Function to take ownership and set full permissions on directory and contents
take_ownership() {
    local dir="$1"
    echo "Taking ownership and setting full permissions on '$dir'..."
    
    # Find all files and directories below target and change ownership and permissions
    find "$dir" -type d -exec chmod 777 {} \; 2>/dev/null
    find "$dir" -type f -exec chmod 666 {} \; 2>/dev/null
    chown -R $(whoami) "$dir" 2>/dev/null
}

# Stop processes using the directory
kill_processes "$TARGET_DIR"

# Unmount any filesystems within the directory
unmount_filesystems "$TARGET_DIR"

# Take ownership of the directory
take_ownership "$TARGET_DIR"

# Optional: Wait a moment for processes to fully terminate
sleep 2

# Final deletion with force options
echo "Removing directory '$TARGET_DIR'..."
rm -rf "$TARGET_DIR"

# Check if directory was successfully deleted
if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory '$TARGET_DIR' has been successfully deleted."
else
    echo "Warning: Directory '$TARGET_DIR' still exists."
    echo "Using more aggressive deletion method..."
    
    # More aggressive approach - set everything to writable and try again
    find "$TARGET_DIR" -type d -exec chmod -R 777 {} \; 2>/dev/null
    find "$TARGET_DIR" -type f -exec chmod -R 666 {} \; 2>/dev/null
    
    # Try delete again with verbose output
    rm -rfv "$TARGET_DIR"
    
    # Final check
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Directory '$TARGET_DIR' has been successfully deleted."
    else
        echo "ERROR: Failed to delete directory '$TARGET_DIR'."
        echo "You may need to reboot the system and try again, or check for any special file attributes."
    fi
fi

exit 0
