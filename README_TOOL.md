# Keyleds Diagnostic and Management Tool

This tool is designed to help maintain and troubleshoot the `keyledsd` service for Logitech G910 keyboards.

## Features

- **Diagnostic**: Comprehensive health check including:
    - **System Context**: Session type (Wayland/X11), Desktop Environment, and Kernel version.
    - **Common log error detection**: DBus conflicts, device busy, and communication resets.
    - Binary integrity and **library version monitoring**.
    - HID device discovery and **active process verification**.
    - **Evdev node accessibility check** (for Wayland/evdev support).
    - Detection of conflicting software like `Solaar` or `keyboard-center`.
    - **Source & Remote change detection**: Alerts if there are unbuilt local changes or new updates on GitHub.
    - **Udev rule verification**.
- **Service Management**:
    - **Restart**: Quickly restarts the `keyledsd` user service.
    - **Toggle Autostart**: Enables or disables the service to start automatically on login.
    - **Fix Conflicts**: Automatically stops conflicting services like Solaar or keyboard-center.
- **Configuration Management**:
    - **Edit**: Opens the configuration file in your default editor (Terminal or Code-OSS).
    - **Backup/Restore**: Easily create timestamped backups or restore from them.
- **Rebuild & Reinstall**: Automates the compilation and installation process from the source fork at `~/Tools/g910/keyleds-fork`.
- **Maintenance**:
    - **Update Tool/Source**: Pulls the latest version from GitHub and syncs the tool.

## Usage

### Interactive Mode
Run the script without arguments to use the interactive menu:
```bash
~/Tools/g910/keyledsd_diagnosis/keyleds-diag.sh
```

### Non-Interactive Mode
You can also run specific actions directly:
```bash
~/Tools/g910/keyledsd_diagnosis/keyleds-diag.sh diag      # Run diagnostics
~/Tools/g910/keyledsd_diagnosis/keyleds-diag.sh restart   # Restart service
~/Tools/g910/keyledsd_diagnosis/keyleds-diag.sh autostart # Toggle autostart
~/Tools/g910/keyledsd_diagnosis/keyleds-diag.sh rebuild   # Rebuild and reinstall
~/Tools/g910/keyledsd_diagnosis/keyleds-diag.sh code      # Edit config with Code-OSS
~/Tools/g910/keyledsd_diagnosis/keyleds-diag.sh update    # Update tool and source
```
