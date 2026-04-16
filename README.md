
<p align="center">
  # <img src="https://github.com/user-attachments/assets/87963f2d-a648-43e4-9910-93dc07b0d635" />
</p>
Add tap-to-click to your Magic Mouse — free and open source.

[![Download](https://img.shields.io/github/v/release/FAZIO11/MagicMouseClick?label=Download)](https://github.com/FAZIO11/MagicMouseClick/releases/latest)
[![Star on GitHub](https://img.shields.io/github/stars/FAZIO11/MagicMouseClick?style=social)](https://github.com/FAZIO11/MagicMouseClick)



## Installation

1. Download **MagicMouseClick-v1.1.dmg** from the [latest release](https://github.com/FAZIO11/MagicMouseClick/releases/latest)
2. Open the DMG → drag **MagicMouseClick** to Applications
3. Double-click the app — macOS will show a security warning. 
   This appears because the app is open-source and not sold 
   through the App Store. It is completely safe.
   Click **Done**.
4. Go to **System Settings → Privacy & Security**
5. Scroll down and click **"Open Anyway"** next to MagicMouseClick
6. Enter your Mac password
7. Grant Accessibility permission when prompted
8. Done — tap your Magic Mouse to click!

> Watch the full setup walkthrough: [https://www.youtube.com/watch?v=91Kkd39EIIo]

## Features

- **1-finger tap** → Left click
- **2-finger tap** → Right click
- Menu bar app — runs quietly in background
- Live visualizer shows touch detection
- Configurable settings via menu bar icon

## Requirements

- macOS 13.0 (Ventura) or later
- Magic Mouse or Magic Mouse 2

## Support the Project

If MagicMouseClick is useful to you, please ⭐ star the repo — it helps others find it!



---

<details>
<summary>For Developers</summary>

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
│  - Scroll disambiguation                               │
│  - Multi-finger session tracking                       │
├─────────────────────────────────────────────────────────┤
│               ClickInjector                            │
│  - CGEvent-based click injection                       │
│  - Double-click detection                              │
├─────────────────────────────────────────────────────────┤
│               System Integration                       │
│  - AutoLaunch for launch at login                      │
│  - AXIsProcessTrusted for accessibility permission      │
└─────────────────────────────────────────────────────────┘
```

## Configuration

- **Tap Duration**: How long a touch can last to register as a tap (100-350ms, default: 180ms)
- **Movement Threshold**: Maximum finger movement allowed during a tap (0.01-0.10, default: 0.03)
- **Enable Right Click**: Toggle 2-finger tap for right click

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

</details>

## License

MIT License - see [LICENSE](LICENSE) for details.


