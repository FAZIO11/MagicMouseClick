# MagicMouseClick

A lightweight macOS utility that enables gesture-based interactions on the Magic Mouse, starting with tap-to-click functionality.

## Features

- **1-finger tap** → Left click
- **2-finger tap** → Right click
- **Menu bar app** with toggle controls
- **Live visualizer** to see touch registration
- **Configurable** tap duration and sensitivity

## Requirements

- macOS 13.0 (Ventura) or later
- Magic Mouse or Magic Mouse 2
- Xcode 15+
- Accessibility permission (guided setup)

## Building

### Prerequisites

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Select Xcode as the active developer directory:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

### Build Steps

```bash
# Navigate to project directory
cd MagicMouseClick

# Generate Xcode project
xcodegen generate

# Open in Xcode (recommended)
open MagicMouseClick.xcodeproj

# Or build from command line
xcodebuild -scheme MagicMouseClick -configuration Release build
```

The built app will be in:
```
DerivedData/MagicMouseClick/Build/Products/Release/MagicMouseClick.app
```

### First Run Setup

1. Copy the app to Applications:
   ```bash
   cp -R DerivedData/MagicMouseClick/Build/Products/Release/MagicMouseClick.app /Applications/
   ```

2. Launch the app from Applications

3. Follow the setup wizard to grant Accessibility permission

4. In System Settings → Privacy & Security → Accessibility, enable MagicMouseClick

## Configuration

- **Tap Duration**: How long a touch must last to register as a tap (100-350ms, default: 180ms)
- **Movement Threshold**: Maximum finger movement allowed during a tap (0.01-0.10, default: 0.03)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Menu Bar UI                          │
│  (StatusItem, Settings Window, Live Visualizer)        │
├─────────────────────────────────────────────────────────┤
│               MultitouchBridge                          │
│  - Dynamic loads MultitouchSupport.framework            │
│  - Registers callbacks for Magic Mouse events           │
│  - Handles device connect/disconnect                     │
├─────────────────────────────────────────────────────────┤
│               GestureRecognizer                        │
│  - Tap detection with duration/movement validation      │
│  - Palm rejection (filters edge touches, large touches)│
│  - Multi-finger session tracking                        │
├─────────────────────────────────────────────────────────┤
│               ClickInjector                            │
│  - CGEvent-based click injection                        │
│  - Debouncing to prevent double-clicks                  │
├─────────────────────────────────────────────────────────┤
│               System Integration                       │
│  - SMAppService for launch at login                     │
│  - AXIsProcessTrusted for accessibility permission     │
└─────────────────────────────────────────────────────────┘
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
