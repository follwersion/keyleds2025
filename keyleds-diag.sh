#!/usr/bin/env bash

# Keyleds Diagnostic Script
# Verifies the health of keyledsd and its environment

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Keyleds Diagnostic ==="

# 1. Check Service Status
echo -n "Checking keyledsd service... "
if systemctl --user is-active --quiet keyledsd; then
    echo -e "${GREEN}ACTIVE${NC}"
else
    echo -e "${RED}INACTIVE${NC}"
    systemctl --user status keyledsd --no-pager
fi

# 2. Check Binary and Libraries
echo -n "Checking keyledsd binary... "
if [ -f /usr/local/bin/keyledsd ]; then
    echo -e "${GREEN}FOUND${NC} (/usr/local/bin/keyledsd)"
    LD_LIBRARY_PATH=/usr/local/lib ldd /usr/local/bin/keyledsd | grep "not found"
    if [ $? -eq 0 ]; then
        echo -e "${RED}ERROR: Missing dependencies!${NC}"
    else
        echo -e "  Dependencies: ${GREEN}OK${NC}"
    fi
    
    # Check for library updates since build
    BINARY_TIME=$(stat -c %Y /usr/local/bin/keyledsd)
    REBUILD_RECOMMENDED=0
    for lib in /usr/lib/libluajit-5.1.so.2 /usr/lib/libuv.so.1 /usr/lib/libyaml-0.so.2; do
        if [ -f "$lib" ]; then
            LIB_TIME=$(stat -c %Y "$lib")
            if [ "$LIB_TIME" -gt "$BINARY_TIME" ]; then
                echo -e "${YELLOW}WARNING: $lib is newer than binary!${NC}"
                REBUILD_RECOMMENDED=1
            fi
        fi
    done
    if [ "$REBUILD_RECOMMENDED" -eq 1 ]; then
        echo -e "${YELLOW}Recommendation: Rebuild keyledsd to ensure compatibility with updated libraries.${NC}"
    fi
else
    echo -e "${RED}NOT FOUND${NC}"
fi

echo -n "Checking libkeyleds... "
if [ -f /usr/local/lib/libkeyleds.so ]; then
    echo -e "${GREEN}FOUND${NC}"
else
    echo -e "${RED}NOT FOUND${NC} (Check /usr/local/lib)"
fi

# 3. Check Devices
echo "Checking HID devices..."
# Look for Logitech G910
G910_HIDS=$(grep -l "0003:0000046D:0000C335" /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null | cut -d/ -f5)
if [ -n "$G910_HIDS" ]; then
    for hid in $G910_HIDS; do
        echo -e "${GREEN}Found G910 on /dev/$hid${NC}"
        # Check permissions
        if [ -r "/dev/$hid" ] && [ -w "/dev/$hid" ]; then
            echo -e "  Permissions (/dev/$hid): ${GREEN}OK${NC}"
        else
            echo -e "  Permissions (/dev/$hid): ${RED}FAILED${NC} (Check udev rules)"
        fi
    done
else
    echo -e "${YELLOW}G910 NOT FOUND via HID identifier${NC}"
fi

# 4. Check Evdev (Wayland compatibility)
echo "Checking Input Event devices..."
# keyledsd now logs when it finds event devices
journalctl --user -u keyledsd -n 50 --no-pager | grep "found event device"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Evdev listener active${NC}"
else
    echo -e "${YELLOW}Evdev listener NOT DETECTED in recent logs${NC}"
fi

# 5. Conflict Check
echo "Checking for potential conflicts..."
if pgrep solaar >/dev/null; then
    echo -e "${YELLOW}WARNING: Solaar is running${NC} (May conflict with HID++ protocol)"
fi
if pgrep -f keyboard-center >/dev/null; then
    echo -e "${YELLOW}WARNING: keyboard-center is running${NC} (May conflict with G/M keys)"
fi

# 6. Check Environment
echo -n "Checking DISPLAY... "
if [ -n "$DISPLAY" ]; then
    echo -e "${GREEN}$DISPLAY${NC}"
else
    echo -e "${RED}NOT SET${NC}"
fi

echo "=== Diagnostic Complete ==="
