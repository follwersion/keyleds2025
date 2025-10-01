# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

**keyleds** is an advanced RGB animation service for Logitech keyboards on Linux. It provides flexible per-application RGB settings, animated effects, and a LUA scripting engine for custom effects.

The project consists of three main components:
- **libkeyleds**: Hardware abstraction library (C99) for communicating with Logitech keyboards via hidraw
- **keyledsd**: Service daemon (C++17) that manages animations, profiles, and effects
- **keyledsctl**: Command-line tool (C99) for keyboard configuration and diagnostics

## Build System

### Basic Commands

```bash
# Configure build (from project root)
cmake -B build -DCMAKE_BUILD_TYPE=MinSizeRel

# Build everything
cmake --build build

# Build specific targets
cmake --build build --target libkeyleds
cmake --build build --target keyledsd
cmake --build build --target keyledsctl

# Install
sudo cmake --install build

# Clean build
rm -rf build
```

### Build Options

Configure with options using `-D` flags:
```bash
cmake -B build -DWITH_KEYLEDSD=ON    # Build keyledsd daemon (default: ON)
cmake -B build -DWITH_PYTHON=ON      # Build Python bindings (default: OFF)
cmake -B build -DWITH_TESTS=ON       # Build test suite (default: OFF)
cmake -B build -DNO_DBUS=ON          # Disable DBus support (default: OFF)
```

### Testing

```bash
# Enable tests during configuration
cmake -B build -DWITH_TESTS=ON

# Build and run tests
cmake --build build
ctest --test-dir build

# Run specific test
./build/bin/test-common
```

## Project Architecture

### Component Structure

```
libkeyleds/          # Hardware abstraction layer (HAL)
├── include/         # Public API headers
└── src/            # Feature implementations (gamemode, gkeys, leds, etc.)

keyledsd/           # Main service daemon
├── src/
│   ├── device/     # Device abstraction and Logitech protocol
│   ├── service/    # Core service logic, DBus interface, effect management
│   └── tools/      # Utilities (animation loop, file watching, X11 integration)
├── plugins/        # Built-in effect plugins (C++)
├── effects/        # LUA effect scripts
└── layouts/        # Keyboard layout definitions (YAML)

keyledsctl/         # Command-line utility
└── src/            # Device enumeration, LED control, info queries
```

### Key Architectural Concepts

**Effect Pipeline**: Effects are rendered in order specified in configuration. Each effect can read and modify the render buffer, allowing for composable animations.

**Profile System**: Profiles match window class/title using regex. When multiple profiles match, the last one wins. The `__default__` profile activates when no other matches, and `__overlay__` applies on top of all profiles.

**Render Loop**: The service maintains a continuous render loop that:
1. Polls X11 for active window context
2. Evaluates profile matches
3. Renders active effects to buffer
4. Pushes buffer to keyboard hardware

**Dynamic Loading**: Effect plugins can be dynamically loaded at runtime. The service supports both static (compiled-in) and dynamic plugin loading.

## Code Conventions

### File Organization

- C source: `.c` files
- C++ source: `.cxx` files  
- Headers (both): `.h` files
- Implementation mirrors header structure: `include/foo/bar.h` → `src/foo/bar.c`

### Naming Conventions

**C++ code:**
- Namespaces: `snake_case`
- Types: `CamelCase` (STL-style exceptions allowed: `iterator`, `foo_list`)
- Variables: `lowerCamelCase`
- Non-public members: `m_` prefix (e.g., `m_fooBar`)
- Functions/methods: `lowerCamelCase`
- Getters: property name without `m_` prefix
- Setters: `set` prefix

**C code:**
- Structures: `snake_case` (may typedef to `CamelCase` for OOP-style use)
- Variables/functions/constants: `snake_case`
- Macros: `UPPERCASE_WITH_UNDERSCORES`

### Code Style

**Braces:**
- Function/type opening brace: new line
- All other blocks: same line as statement
- `else` keyword: same line as closing `}`
- Always use braces, even for single statements

**Memory Management (C++):**
- Use `std::unique_ptr` for ownership
- Raw pointers are non-owning only
- No naked `new`/`delete` (except RenderTarget)
- RAII for all resources

**Compilation:**
- C++17 standard, no RTTI (`-fno-rtti`)
- C99 standard for C code
- 4 spaces per indent, UTF-8, Unix line endings

## Development Workflow

### Adding a New Effect Plugin

1. Create plugin source in `keyledsd/plugins/src/`
2. Implement plugin interface with `run()` method
3. Register plugin in `keyledsd/src/service/StaticModuleRegistry.cxx`
4. Add to `keyledsd/plugins/CMakeLists.txt`
5. Document effect parameters in sample config

### Adding Keyboard Layout

1. Create YAML file in `keyledsd/layouts/`
2. Define key positions, LED indices, and physical layout
3. Test with `keyledsctl -d /dev/hidraw* info`

### Working with LUA Effects

LUA effects live in `keyledsd/effects/`. They have access to:
- Key database (positions, LED indices)
- RenderTarget methods (fill, blend operations)
- Custom DBus events
- Keyboard events (key presses)

Reference existing effects in the `effects/` directory for examples.

## Debugging

### Useful Commands

```bash
# List all detected Logitech devices
keyledsctl list

# Get device information
keyledsctl -d /dev/hidraw0 info

# Test LED control
keyledsctl -d /dev/hidraw0 set-leds off
keyledsctl -d /dev/hidraw0 set-leds F1-F12:red

# Monitor service logs
journalctl -u keyledsd -f

# Run service in foreground with debug output
keyledsd -vv
```

### Common Issues

**Permissions**: Ensure user has access to hidraw devices (install udev rules: `logitech.rules`)

**G-keys not working**: Check G-key mask configuration with `keyledsctl gkeys`

**X11 context not detected**: Verify `DISPLAY` environment variable and X11 permissions

## Configuration

Default config location: `~/.config/keyledsd.conf` or `/etc/keyledsd.conf`

Sample configuration: `keyledsd/keyledsd.conf.sample`

Config supports:
- Key groups (reusable sets of keys)
- Custom color aliases
- Profile matching on window class/title
- Effect stacking and composition
- Nested key group definitions
