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
- Fixed animation timing in Lua plugins by correctly passing delta time instead of total elapsed time.

### Wayland Compatibility
- Added direct `evdev` event listener to capture keyboard events independently of X11/XWayland, enabling key-reactive effects on Wayland sessions.

### G910 Layout Fixes
- Fixed G910 keyboard layout loading
- Layout symlinks now properly reference actual layout files

### Systemd Service Template
- Added `keyledsd.service.example` for easy systemd user service setup
- Includes proper `LD_LIBRARY_PATH` configuration
- Enables automatic startup on login

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

## Verified Working Features

✅ Build completes without errors  
✅ All keyboard models supported  
✅ LED control and animations  
✅ LUA scripting effects  
✅ Profile switching  
✅ G-keys support  
✅ Systemd autostart  

## Issues Fixed

- #4629: CMake 4.x compatibility
- G910 layout loading errors
- Library path issues with /usr/local installation
- Missing systemd service template

## Contributing

If these fixes work for you, please star the repository and consider contributing back to the upstream project!
