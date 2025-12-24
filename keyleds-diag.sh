#!/usr/bin/env bash

# Keyleds Diagnostic and Management Tool
# This tool helps in identifying issues with keyledsd and provides 
# quick actions to restart, rebuild, or reinstall the service.
#
# Usage: ./keyleds-diag.sh
# 
# Features:
# - Diagnostic health check (service, binary, deps, devices, conflicts)
# - Service management (restart)
# - Source-based rebuild and reinstall
# - Interactive menu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FORK_PATH="/home/dolbergkon/g910/keyleds-fork"

run_diagnostic() {
    echo ""
    echo "=== Keyleds Diagnostic ==="

    # 0. System Context
    echo "Checking system context..."
    KERNEL=$(uname -r)
    SESSION_TYPE=$XDG_SESSION_TYPE
    DE=$XDG_CURRENT_DESKTOP
    echo -e "  Kernel: ${GREEN}$KERNEL${NC}"
    echo -e "  Session: ${GREEN}$SESSION_TYPE${NC}"
    echo -e "  Desktop: ${GREEN}$DE${NC}"

    # 1. Check Service Status
    echo -n "Checking keyledsd service... "
    if systemctl --user is-active --quiet keyledsd; then
        echo -e "${GREEN}ACTIVE${NC}"
    else
        echo -e "${RED}INACTIVE${NC}"
        systemctl --user status keyledsd --no-pager
    fi

    # 1.1 Check for common service errors in logs
    echo "Scanning logs for common issues..."
    LOG_ERRORS=$(journalctl --user -u keyledsd -n 50 --no-pager)
    if echo "$LOG_ERRORS" | grep -q "Could not reserve name on session bus"; then
        echo -e "  ${RED}ERROR: DBus name conflict detected!${NC} (Another instance might be running)"
    fi
    if echo "$LOG_ERRORS" | grep -q "device busy"; then
        echo -e "  ${YELLOW}WARNING: Device busy errors found${NC} (Check for conflicts with Solaar/keyboard-center)"
    fi
    if echo "$LOG_ERRORS" | grep -q "re-syncing device"; then
        echo -e "  ${YELLOW}WARNING: Communication resets found${NC} (May indicate unstable connection)"
    fi

    # 2. Check Binary and Libraries
    echo -n "Checking keyledsd binary... "
    if [ -f /usr/local/bin/keyledsd ]; then
        echo -e "${GREEN}FOUND${NC} (/usr/local/bin/keyledsd)"
        MISSING_DEPS=$(LD_LIBRARY_PATH=/usr/local/lib ldd /usr/local/bin/keyledsd | grep "not found")
        if [ -n "$MISSING_DEPS" ]; then
            echo -e "${RED}ERROR: Missing dependencies!${NC}"
            echo "$MISSING_DEPS"
        else
            echo -e "  Dependencies: ${GREEN}OK${NC}"
        fi
        
        # Check for library updates since build
        BINARY_TIME=$(stat -c %Y /usr/local/bin/keyledsd)
        REBUILD_RECOMMENDED=0
        # List of critical dependencies
        DEPS=("/usr/lib/libluajit-5.1.so.2" "/usr/lib/libuv.so.1" "/usr/lib/libyaml-0.so.2" "/usr/local/lib/libkeyleds.so")
        for lib in "${DEPS[@]}"; do
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

    # 3. Check Devices and FDs
    echo "Checking HID devices..."
    G910_HIDS=$(grep -l "0003:0000046D:0000C335" /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null | cut -d/ -f5)
    if [ -n "$G910_HIDS" ]; then
        PID=$(pgrep -u "$USER" keyledsd | head -n 1)
        for hid in $G910_HIDS; do
            echo -e "${GREEN}Found G910 on /dev/$hid${NC}"
            if [ -r "/dev/$hid" ] && [ -w "/dev/$hid" ]; then
                echo -e "  Permissions (/dev/$hid): ${GREEN}OK${NC}"
            else
                echo -e "  Permissions (/dev/$hid): ${RED}FAILED${NC} (Check udev rules)"
            fi
            # Check if process has it open
            if [ -n "$PID" ]; then
                if ls -l "/proc/$PID/fd" 2>/dev/null | grep -q "$hid"; then
                    echo -e "  Process link: ${GREEN}ACTIVE${NC}"
                else
                    echo -e "  Process link: ${YELLOW}NOT OPENED BY SERVICE${NC}"
                fi
            fi
        done
    else
        echo -e "${YELLOW}G910 NOT FOUND via HID identifier${NC}"
    fi

    # 4. Check Evdev (Wayland compatibility)
    echo "Checking Input Event devices..."
    # Find event nodes for G910
    EVENT_NODES=$(ls -d /sys/class/hidraw/hidraw*/device/input/input*/event* 2>/dev/null | xargs -I {} basename {} 2>/dev/null)
    if [ -n "$EVENT_NODES" ]; then
        for ev in $EVENT_NODES; do
            echo -n "  Checking /dev/input/$ev... "
            if [ -r "/dev/input/$ev" ]; then
                echo -e "${GREEN}READABLE${NC}"
            else
                echo -e "${RED}NOT READABLE${NC} (Requires 'input' group or udev rule)"
            fi
        done
    fi

    journalctl --user -u keyledsd -n 100 --no-pager | grep -q "found event device"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Evdev listener active in logs${NC}"
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

    # 7. Check Config
    echo -n "Checking keyledsd configuration... "
    CONF_FILE="$HOME/.config/keyledsd.conf"
    if [ -f "$CONF_FILE" ]; then
        VAL_OUT=$(LD_LIBRARY_PATH=/usr/local/lib /usr/local/bin/keyledsd -c "$CONF_FILE" -D 2>&1)
        # If output contains "plugins:", it's valid. 
        # If it fails with DBus error, we can't be sure but it's likely fine if YAML is valid.
        if echo "$VAL_OUT" | grep -q "plugins:"; then
            echo -e "${GREEN}VALID${NC}"
        elif echo "$VAL_OUT" | grep -q "Could not reserve name on session bus"; then
            # Fallback to Python YAML check
            if python3 -c 'import yaml; yaml.safe_load(open("'$CONF_FILE'"))' 2>/dev/null; then
                echo -e "${GREEN}VALID${NC} (YAML syntax OK, DBus busy)"
            else
                echo -e "${RED}INVALID${NC} (YAML syntax error)"
                python3 -c 'import yaml; yaml.safe_load(open("'$CONF_FILE'"))' 2>&1 | head -n 5
            fi
        else
            echo -e "${RED}INVALID${NC}"
            echo "$VAL_OUT" | grep -ivE "Could not reserve name|session bus" | head -n 5
        fi
    else
        echo -e "${RED}MISSING${NC} ($CONF_FILE)"
    fi

    # 8. Check Source and Remote changes
    if [ -d "$FORK_PATH" ]; then
        echo -n "Checking for unbuilt source changes... "
        LATEST_SRC=$(find "$FORK_PATH/keyledsd/src" "$FORK_PATH/libkeyleds/src" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f1 -d' ')
        if [ -n "$LATEST_SRC" ]; then
            LATEST_SRC_INT=${LATEST_SRC%.*}
            if [ "$LATEST_SRC_INT" -gt "$BINARY_TIME" ]; then
                echo -e "${YELLOW}CHANGES DETECTED${NC} (Source is newer than binary)"
                REBUILD_RECOMMENDED=1
            else
                echo -e "${GREEN}UP TO DATE${NC}"
            fi
        fi

        echo -n "Checking for remote updates... "
        cd "$FORK_PATH" || return
        git fetch --quiet origin master 2>/dev/null
        UPSTREAM=${1:-'@{u}'}
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse "$UPSTREAM")
        BASE=$(git merge-base @ "$UPSTREAM")

        if [ "$LOCAL" = "$REMOTE" ]; then
            echo -e "${GREEN}Local fork is up to date with origin${NC}"
        elif [ "$LOCAL" = "$BASE" ]; then
            echo -e "${YELLOW}NEED PULL${NC} (Origin has new updates)"
        elif [ "$REMOTE" = "$BASE" ]; then
            echo -e "${YELLOW}NEED PUSH${NC} (Local has unpushed changes)"
        else
            echo -e "${RED}DIVERGED${NC}"
        fi
        cd - >/dev/null || return
    fi

    # 9. Check Udev rules
    echo -n "Checking udev rules... "
    if [ -f /etc/udev/rules.d/logitech-g910.rules ] || [ -f /usr/lib/udev/rules.d/logitech-g910.rules ]; then
        echo -e "${GREEN}FOUND${NC}"
    else
        echo -e "${YELLOW}NOT FOUND${NC} (Expected logitech-g910.rules)"
    fi

    if [ "$REBUILD_RECOMMENDED" -eq 1 ]; then
        echo -e "${YELLOW}Recommendation: Rebuild keyledsd (Option 3) to apply latest changes and ensure library compatibility.${NC}"
    fi

    echo "=== Diagnostic Complete ==="
}

restart_service() {
    echo ""
    echo "Restarting keyledsd service..."
    systemctl --user restart keyledsd
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Service restarted successfully.${NC}"
    else
        echo -e "${RED}Failed to restart service.${NC}"
    fi
}

rebuild_reinstall() {
    echo ""
    echo "Rebuilding and reinstalling from $FORK_PATH..."
    if [ ! -d "$FORK_PATH" ]; then
        echo -e "${RED}Error: Fork directory not found at $FORK_PATH${NC}"
        return 1
    fi
    
    local CURRENT_DIR=$(pwd)
    cd "$FORK_PATH" || return 1
    
    echo "Configuring..."
    cmake -B build -DCMAKE_BUILD_TYPE=MinSizeRel
    if [ $? -ne 0 ]; then
        echo -e "${RED}Configuration failed.${NC}"
        cd "$CURRENT_DIR" || exit
        return 1
    fi
    
    echo "Building..."
    cmake --build build -j$(nproc)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Build failed.${NC}"
        cd "$CURRENT_DIR" || exit
        return 1
    fi
    
    echo "Installing (sudo password might be required)..."
    sudo cmake --install build
    if [ $? -ne 0 ]; then
        echo -e "${RED}Installation failed.${NC}"
        cd "$CURRENT_DIR" || exit
        return 1
    fi
    
    echo -e "${GREEN}Reinstall complete.${NC}"
    restart_service
    cd "$CURRENT_DIR" || exit
}

fix_conflicts() {
    echo ""
    echo "Stopping conflicting services..."
    if pgrep solaar >/dev/null; then
        echo -n "Stopping Solaar... "
        pkill solaar && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAILED${NC}"
    fi
    if pgrep -f keyboard-center >/dev/null; then
        echo -n "Stopping keyboard-center... "
        pkill -f keyboard-center && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAILED${NC}"
    fi
}

backup_config() {
    local CONF_FILE="$HOME/.config/keyledsd.conf"
    local BACKUP_FILE="$HOME/.config/keyledsd.conf.bak.$(date +%Y%m%d_%H%M%S)"
    if [ -f "$CONF_FILE" ]; then
        cp "$CONF_FILE" "$BACKUP_FILE"
        echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"
    else
        echo -e "${RED}Configuration file not found.${NC}"
    fi
}

restore_config() {
    local CONF_DIR="$HOME/.config"
    echo "Available backups:"
    ls -1 "$CONF_DIR"/keyledsd.conf.bak* 2>/dev/null
    echo -n "Enter full path of backup to restore (or 'q' to cancel): "
    read -r backup_path
    if [ "$backup_path" = "q" ]; then return; fi
    if [ -f "$backup_path" ]; then
        cp "$backup_path" "$HOME/.config/keyledsd.conf"
        echo -e "${GREEN}Configuration restored. Restarting service...${NC}"
        restart_service
    else
        echo -e "${RED}Backup file not found.${NC}"
    fi
}

edit_config() {
    local CONF_FILE="$HOME/.config/keyledsd.conf"
    local EDITOR=${EDITOR:-nano}
    if [ -f "$CONF_FILE" ]; then
        $EDITOR "$CONF_FILE"
        echo "Reloading configuration..."
        restart_service
    else
        echo -e "${RED}Configuration file not found.${NC}"
    fi
}

show_menu() {
    echo ""
    echo "Keyleds Management Tool"
    echo "-----------------------"
    echo "1) Run Diagnostic"
    echo "2) Restart Service"
    echo "3) Rebuild & Reinstall"
    echo "4) Fix Conflicts (Kill Solaar/KC)"
    echo "5) Edit Configuration"
    echo "6) Backup Configuration"
    echo "7) Restore Configuration"
    echo "q) Quit"
    echo ""
    echo -n "Select an option: "
}

# If arguments are provided, skip menu
if [ $# -gt 0 ]; then
    case $1 in
        diag|diagnostic) run_diagnostic ;;
        restart) restart_service ;;
        rebuild|reinstall) rebuild_reinstall ;;
        fix) fix_conflicts ;;
        edit) edit_config ;;
        backup) backup_config ;;
        restore) restore_config ;;
        *) echo "Unknown command: $1" ;;
    esac
    exit 0
fi

# Interactive mode
while true; do
    show_menu
    read -r opt
    case $opt in
        1) run_diagnostic ;;
        2) restart_service ;;
        3) rebuild_reinstall ;;
        4) fix_conflicts ;;
        5) edit_config ;;
        6) backup_config ;;
        7) restore_config ;;
        q|quit|exit) exit 0 ;;
        "") continue ;;
        *) echo "Invalid option: $opt" ;;
    esac
done
