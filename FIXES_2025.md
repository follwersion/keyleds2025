# 2025 Compatibility Fixes

This fork contains fixes for building and running keyleds on modern Linux distributions (2025).

## Changes Made

### CMake 4.x Compatibility
- Updated all `cmake_minimum_required` from VERSION 3.0 to VERSION 3.5
- This fixes the build error: "Compatibility with CMake < 3.5 has been removed"
- Tested with CMake 4.1.1

### Lua Plugin Fixes
- Fixed a bug in `reactive-hlines.lua` where the animation buffer was being garbage collected prematurely due to weak table values.
- Implemented `__eq` operator for Lua `Key` objects to allow reliable key comparisons.

### Wayland Compatibility
- Added direct `evdev` event listener to capture keyboard events independently of X11/XWayland, enabling key-reactive effects on Wayland sessions. Key delivery is gated per session type (evdev on Wayland, XInput on X11) so a keypress is not dispatched twice.

### Systemd Service Template
- Added `keyledsd.service.example` for easy systemd user service setup
- Includes proper `LD_LIBRARY_PATH` configuration
- Enables automatic startup on login

### Resilience and Error Recovery
- Improved error recovery logic in `RenderLoop`: Added exponential backoff and increased retry attempts (up to 10) for device communication errors.
- Graceful Conflict Handling: The service now specifically detects and logs potential software conflicts (e.g., with Solaar or keyboard-center) when receiving `EBUSY` or `EAGAIN` errors from the device.
- Enhanced Logging: Evdev listener attachment is now logged at `INFO` level for easier verification.
- Virtual Error Interface: Added `oserror()` to the `Device::error` interface to allow inspection of system error codes.

### Hardware Permissions
- Added `logitech-g910.rules` granting access to the active console user via `TAG+="uaccess"` (logind ACLs), so the service reaches HID and evdev nodes without root privileges and without world-readable input devices.

### Documentation
- Added `WARP.md` for AI assistant guidance
- Added `keyleds-diag.sh` diagnostic and health-check tool
- Comprehensive build and usage instructions

## Tested Configuration

- **OS**: Manjaro Linux / Arch Linux (2025)
- **Kernel**: 6.x+
- **CMake**: 4.1.1
- **Compiler**: GCC 15.2.1
- **LUA**: LuaJIT 2.1
- **Hardware**: Logitech G910 Orion Spectrum

## Build Instructions

```bash
# Install dependencies
sudo pacman -S cmake gcc luajit libuv libsystemd libyaml libx11 libudev

# Configure
cmake -B build -DCMAKE_BUILD_TYPE=MinSizeRel

# Build
cmake --build build -j$(nproc)

# Install
sudo cmake --install build

# Setup systemd service
mkdir -p ~/.config/systemd/user
cp keyledsd.service.example ~/.config/systemd/user/keyledsd.service
systemctl --user daemon-reload
systemctl --user enable --now keyledsd.service
```

## Verified Working (Logitech G910)

✅ Build completes without errors  
✅ LED control and animations  
✅ LUA scripting effects  
✅ Systemd autostart  

## Issues Fixed

- CMake 4.x compatibility
- Library path issues with /usr/local installation
- Missing systemd service template

## Contributing

If these fixes work for you, please star the repository and consider contributing back to the upstream project!
