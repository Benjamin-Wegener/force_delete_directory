# Force Delete Directory

A powerful shell script to forcefully delete directories and their contents by handling common obstacles like permissions, running processes, and mounted filesystems.

![GitHub License](https://img.shields.io/github/license/Benjamin-Wegener/force_delete_directory)

## Quick Start

Run without installation (requires sudo privileges):

```bash
curl -s https://raw.githubusercontent.com/Benjamin-Wegener/force_delete_directory/main/force_delete_directory.sh | sudo bash -s -- /path/to/directory
```

## Overview

This tool solves the frustrating problem of directories that resist deletion through standard methods. When you need to remove a directory that's locked by permissions, running processes, or active mounts, this script provides a comprehensive solution.

## Features

- **Permission Handling**: Takes ownership and sets full permissions on all files
- **Process Management**: Identifies and terminates processes using files in the target directory
- **Mount Handling**: Safely unmounts any filesystems within the target directory
- **Progressive Approach**: Tries increasingly aggressive methods if initial deletion fails
- **Safety First**: Requires explicit confirmation before proceeding

## Installation

### Method 1: Clone the Repository

```bash
git clone https://github.com/Benjamin-Wegener/force_delete_directory.git
cd force_delete_directory
chmod +x force_delete.sh
```

### Method 2: Download the Script Directly

```bash
curl -O https://raw.githubusercontent.com/Benjamin-Wegener/force_delete_directory/main/force_delete.sh
chmod +x force_delete.sh
```

## Usage

The script requires root privileges to handle all potential permission issues:

```bash
sudo ./force_delete.sh /path/to/directory
```

### Example

```bash
$ sudo ./force_delete.sh /var/www/problematic_site

WARNING: This script will forcefully delete '/var/www/problematic_site' and ALL its contents.
This action cannot be undone. Are you sure you want to continue? (y/N)
y
Starting forced deletion of '/var/www/problematic_site'...
Finding and killing processes using '/var/www/problematic_site'...
Killing process 1234 (apache2)
Checking for and unmounting filesystems under '/var/www/problematic_site'...
Taking ownership and setting full permissions on '/var/www/problematic_site'...
Removing directory '/var/www/problematic_site'...
Directory '/var/www/problematic_site' has been successfully deleted.
```

## How It Works

The script follows this process:

1. **Validation**: Verifies the script has necessary permissions and a valid target
2. **Confirmation**: Requires explicit confirmation before proceeding
3. **Process Termination**: Identifies and kills processes locking files
4. **Filesystem Management**: Unmounts any filesystems within the target
5. **Permission Reset**: Takes ownership and sets permissive access rights
6. **Deletion**: Attempts to remove the directory using standard methods
7. **Escalation**: If standard deletion fails, applies more aggressive techniques

## Common Use Cases

- Removing corrupted application directories
- Cleaning up problematic Docker volumes
- Deleting directories with incorrect ownership
- Removing directories containing mounted points
- Clearing directories locked by unresponsive processes

## Troubleshooting

If the script fails to delete a directory:

1. **Reboot the System**: Some kernel-level locks may require a system restart
2. **Check for Special Attributes**: Use `lsattr` to identify special file attributes
3. **Examine System Logs**: Look for specific errors in system logs with `dmesg`

## Security Considerations

This script requires root privileges and can forcefully delete files. Use with caution:

- Always double-check the path you provide
- Be especially careful when using with system directories
- Consider backing up important data before running on critical paths

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the frustration of dealing with stubborn directories
- Thanks to the Linux community for various techniques incorporated here
