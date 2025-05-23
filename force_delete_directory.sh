#!/bin/bash

# Force Delete Directory Script
# This script forcefully deletes a directory and all its contents
# Handles permissions, running processes, mounts, and nested chroot mounts

# Print colored status messages
print_status() {
    local color="$1"
    local message="$2"

    # Color codes
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color

    # Select color
    case "$color" in
        "red") local COLOR="$RED" ;;
        "green") local COLOR="$GREEN" ;;
        "yellow") local COLOR="$YELLOW" ;;
        "blue") local COLOR="$BLUE" ;;
        *) local COLOR="$NC" ;;
    esac

    echo -e "${COLOR}[STATUS] $message${NC}"
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    print_status "red" "This script requires root privileges to handle all permissions."
    echo "Please run with sudo: sudo $0 <directory_path>"
    exit 1
fi

# Check if directory path is provided
if [ -z "$1" ]; then
    print_status "yellow" "Usage: $0 <directory_path> [-y|--yes]"
    echo "Please provide the full path to the directory you want to delete."
    exit 1
fi

TARGET_DIR="$1"
FORCE_YES=false

# Check for -y or --yes option (can be in any position)
for arg in "$@"; do
    if [ "$arg" = "-y" ] || [ "$arg" = "--yes" ]; then
        FORCE_YES=true
        break
    fi
done

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    print_status "red" "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

print_status "blue" "Target directory: $TARGET_DIR"
echo "Size: $(du -sh "$TARGET_DIR" 2>/dev/null | cut -f1 || echo "unknown")"

# Confirmation handling
if [ "$FORCE_YES" = true ]; then
    print_status "yellow" "This script will forcefully delete '$TARGET_DIR' and ALL its contents."
    echo "Proceeding without confirmation due to -y/--yes flag..."
else
    print_status "yellow" "WARNING: This script will forcefully delete '$TARGET_DIR' and ALL its contents."
    echo "This action cannot be undone. Are you sure you want to continue? (y/N)"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_status "blue" "Operation canceled."
        exit 0
    fi
fi

print_status "green" "Starting forced deletion of '$TARGET_DIR'..."

# Function to find and stop processes using the directory
kill_processes() {
    local dir="$1"
    print_status "blue" "Finding and killing processes using '$dir'..."

    # Find processes using files in the directory
    local procs=$(lsof +D "$dir" 2>/dev/null | awk '{if (NR>1) print $2}' | sort -u)

    if [ -z "$procs" ]; then
        echo "No processes found using the directory."
        return 0
    fi

    for pid in $procs; do
        if [ -n "$pid" ]; then
            echo "Killing process $pid ($(ps -p "$pid" -o comm= 2>/dev/null))"
            kill -9 "$pid" 2>/dev/null
            sleep 0.1
        fi
    done

    echo "All processes terminated."
}

# Function to unmount any filesystems mounted within the target directory
unmount_filesystems() {
    local dir="$1"
    print_status "blue" "Checking for and unmounting filesystems under '$dir'..."

    # Find all mount points under the directory
    local mounts=$(mount | grep -E "on $dir(/|\s)" | awk '{print $3}' | sort -r)

    if [ -z "$mounts" ]; then
        echo "No mounted filesystems found under the directory."
        return 0
    fi

    for mount_point in $mounts; do
        echo "Unmounting $mount_point"
        umount -f "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null

        # Check if unmount was successful
        if mountpoint -q "$mount_point"; then
            echo "Warning: Could not unmount $mount_point. Trying lazy unmount..."
            umount -l "$mount_point"
        fi
    done

    echo "All filesystems unmounted."
}

# Function to unmount nested mounts like chroot
unmount_chroot_style() {
    local dir="$1"
    print_status "blue" "Checking for nested mounts (e.g., chroot) under '$dir'..."

    # Find all mount points inside the target directory recursively
    while read -r mount_point; do
        echo "Unmounting nested mount at $mount_point"
        umount -f "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null

        if mountpoint -q "$mount_point"; then
            echo "ERROR: Could not unmount $mount_point. It might be busy or corrupted."
            return 1
        fi
    done < <(grep -E " /.*$dir" /proc/mounts | awk '{print $2}' | sort -r)

    echo "All nested mounts handled."
}

# Function to take ownership and set full permissions on directory and contents
take_ownership() {
    local dir="$1"
    print_status "blue" "Taking ownership and setting full permissions on '$dir'..."

    # First handle top level directory to make it accessible
    echo "Setting permissions on top level directory..."
    chmod 777 "$dir" 2>/dev/null
    chown $(whoami) "$dir" 2>/dev/null

    # Count items for progress reporting
    local file_count=$(find "$dir" -type f | wc -l)
    local dir_count=$(find "$dir" -type d | wc -l)
    echo "Found approximately $file_count files and $dir_count directories to process"

    # Process directories first
    echo "Setting permissions on directories..."
    local counter=0
    local total_dirs=$((dir_count > 0 ? dir_count : 1))  # Avoid division by zero
    find "$dir" -type d | while read -r directory; do
        chmod 777 "$directory" 2>/dev/null
        counter=$((counter + 1))
        # Show progress every 100 items or for small directories
        if [ $((counter % 100)) -eq 0 ] || [ $total_dirs -lt 100 ]; then
            printf "\rProgress: %d/%d directories (%d%%)" $counter $total_dirs $((counter * 100 / total_dirs))
        fi
    done
    printf "\rProgress: %d/%d directories (100%%)      \n" $dir_count $dir_count

    # Then process files
    echo "Setting permissions on files..."
    counter=0
    local total_files=$((file_count > 0 ? file_count : 1))  # Avoid division by zero
    find "$dir" -type f | while read -r file; do
        chmod 666 "$file" 2>/dev/null
        counter=$((counter + 1))
        # Show progress every 100 items or for small file sets
        if [ $((counter % 100)) -eq 0 ] || [ $total_files -lt 100 ]; then
            printf "\rProgress: %d/%d files (%d%%)" $counter $total_files $((counter * 100 / total_files))
        fi
    done
    printf "\rProgress: %d/%d files (100%%)      \n" $file_count $file_count

    # Change ownership of everything
    echo "Changing ownership of all files and directories..."
    chown -R $(whoami) "$dir" 2>/dev/null

    echo "Permission changes complete."
}

# Track execution time
start_time=$(date +%s)

# Stop processes using the directory
kill_processes "$TARGET_DIR"

# Unmount any filesystems within the directory
unmount_filesystems "$TARGET_DIR"

# Try deletion after unmounting
if [ -d "$TARGET_DIR" ]; then
    print_status "blue" "Trying early deletion after unmounting..."
    rm -rf "$TARGET_DIR" 2>/dev/null
fi

# If still exists, try unmounting nested/chroot mounts
if [ -d "$TARGET_DIR" ]; then
    unmount_chroot_style "$TARGET_DIR"
fi

# Try deletion again after nested unmount
if [ -d "$TARGET_DIR" ]; then
    print_status "blue" "Trying deletion after nested unmount..."
    rm -rf "$TARGET_DIR" 2>/dev/null
fi

# If still exists, take ownership and try again
if [ -d "$TARGET_DIR" ]; then
    take_ownership "$TARGET_DIR"
    rm -rf "$TARGET_DIR" 2>/dev/null
fi

# Final check
if [ ! -d "$TARGET_DIR" ]; then
    print_status "green" "SUCCESS: Directory '$TARGET_DIR' has been deleted."
else
    print_status "yellow" "Warning: Directory '$TARGET_DIR' still exists."
    echo "Using more aggressive deletion method..."

    # More aggressive approach - set everything to writable and try again
    echo "Setting all files and directories to fully writable..."
    find "$TARGET_DIR" -type d -exec chmod -R 777 {} \; 2>/dev/null
    find "$TARGET_DIR" -type f -exec chmod -R 666 {} \; 2>/dev/null

    # Try delete again with verbose output
    echo "Attempting deletion with verbose output..."
    rm -rfv "$TARGET_DIR"

    # Final final check
    if [ ! -d "$TARGET_DIR" ]; then
        print_status "green" "SUCCESS: Directory '$TARGET_DIR' has been successfully deleted."
    else
        print_status "red" "ERROR: Failed to delete directory '$TARGET_DIR'."
        echo "You may need to reboot the system and try again, or check for any special file attributes."
    fi
fi

# Display execution time
end_time=$(date +%s)
execution_time=$((end_time - start_time))
print_status "blue" "Execution completed in ${execution_time} seconds."

exit 0
