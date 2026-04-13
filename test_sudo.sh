#!/bin/bash

# MagicMouseClick - Debug Test Script
# Run with sudo to bypass permission restrictions

echo "=============================================="
echo "MagicMouseClick Debug Test (sudo mode)"
echo "=============================================="

APP_PATH="/Users/fazilsathar/Library/Developer/Xcode/DerivedData/MagicMouseClick-fxsrtjvsatphwmhcrpuljezrsbzs/Build/Products/Debug/MagicMouseClick.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at $APP_PATH"
    echo "Please build the project first!"
    exit 1
fi

echo "App path: $APP_PATH"
echo ""
echo "Running with sudo - this will show all debug output..."
echo ""
echo "=============================================="
echo ""

# Run with sudo and capture all output
sudo "$APP_PATH/Contents/MacOS/MagicMouseClick" 2>&1 | tee ~/Desktop/MagicMouseClick_sudo_debug.log

echo ""
echo "=============================================="
echo "Debug output saved to ~/Desktop/MagicMouseClick_sudo_debug.log"
echo "=============================================="
