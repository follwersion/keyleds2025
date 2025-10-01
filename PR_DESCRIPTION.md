# PR to Upstream: Fix CMake 4.x compatibility and add 2025 improvements

## Problem
Building keyleds with CMake 4.x fails with the error:
```
Compatibility with CMake < 3.5 has been removed from CMake
```

This affects users on modern Linux distributions (Arch, Manjaro, Fedora, etc.) that have upgraded to CMake 4.x, preventing them from building keyleds from source.

## Root Cause
The project specifies `cmake_minimum_required(VERSION 3.0)` in all CMakeLists.txt files. CMake 4.0+ has removed support for minimum version declarations below 3.5, causing immediate configuration failures.

## Solution
This PR updates the minimum CMake version requirement from 3.0 to 3.5 across all build files. This ensures:
- ✅ Compatibility with CMake 4.x (current stable)
- ✅ Backward compatibility maintained (CMake 3.5 was released in 2016)
- ✅ No functional changes to the build process
- ✅ No breaking changes for existing users

## Changes Made

### 1. CMake Compatibility Fix
Updated `cmake_minimum_required` to VERSION 3.5 in:
- `/CMakeLists.txt`
- `/keyledsctl/CMakeLists.txt`
- `/keyledsd/CMakeLists.txt`
- `/keyledsd/plugins/CMakeLists.txt`
- `/libkeyleds/CMakeLists.txt`
- `/python/CMakeLists.txt`

### 2. Documentation Improvements
- **FIXES_2025.md**: Comprehensive guide for building on modern systems
- **keyledsd.service.example**: Systemd user service template with proper library paths
- **WARP.md**: AI assistant guidance for future development

## Testing

Thoroughly tested on:
- **OS**: Manjaro Linux / Arch Linux (kernel 6.x)
- **CMake**: 4.1.1
- **Compiler**: GCC 15.2.1
- **Python**: 3.12
- **LUA**: LuaJIT 2.1.1753364724
- **Hardware**: Logitech G910 Orion Spectrum

### Verified Working Features
✅ CMake configuration completes without errors  
✅ All targets build successfully (libkeyleds, keyledsd, keyledsctl)  
✅ Keyboard detection and initialization  
✅ LED control and animations (all effects)  
✅ LUA scripting engine and effects  
✅ Profile switching based on window context  
✅ G-keys support and configuration  
✅ Systemd service integration  

### Build Verification
```bash
cmake -B build -DCMAKE_BUILD_TYPE=MinSizeRel
cmake --build build -j$(nproc)
sudo cmake --install build
```
All commands complete successfully with no errors or warnings related to CMake version.

## Additional Benefits

### Systemd Service Template
Added `keyledsd.service.example` to simplify setup for users installing to `/usr/local`. The template includes:
- Proper `LD_LIBRARY_PATH` configuration
- Automatic restart on failure
- Priority adjustment for smooth animations
- Journal logging integration

### Modern Distribution Support
The documentation now includes specific instructions for Arch/Manjaro users, helping them get started quickly without hunting for dependency names or configuration examples.

## Backward Compatibility

CMake 3.5 was released in March 2016 and is available on:
- Ubuntu 16.04 LTS and later
- Debian 9 (Stretch) and later
- CentOS 7 (via EPEL)
- All current major distributions

This change maintains excellent backward compatibility while fixing the immediate issue with CMake 4.x.

## Migration Path

For users on very old systems with CMake < 3.5, they can:
1. Continue using the previous release
2. Upgrade CMake (widely available via backports)
3. Build CMake from source (if absolutely necessary)

Given that CMake 3.5 is 9 years old, this should affect a negligible number of users.

## Breaking Changes

**None**. This is a minimal, non-breaking change that only updates the minimum version requirement.

## Checklist

- [x] Tested on target hardware (G910)
- [x] All features verified working
- [x] No functional changes to codebase
- [x] Documentation updated
- [x] Backward compatibility maintained
- [x] Build succeeds on modern systems

## References

- CMake 4.0 Release Notes: https://cmake.org/cmake/help/latest/release/4.0.html
- CMake 3.5 Documentation: https://cmake.org/cmake/help/v3.5/
- Original Issue: Users unable to build on Arch/Manjaro with CMake 4.x

---

**Note**: This PR is ready to merge and addresses a critical blocker for users on current Linux distributions.
