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
- Accessibility permission (guided setup)

## Building

### Prerequisites

- Xcode 15+
- XcodeGen (`brew install xcodegen`)

### Build Steps

```bash
# Clone the repository
git clone https://github.com/fazilsathar/MagicMouseClick.git
cd MagicMouseClick

# Generate Xcode project
xcodegen generate

# Open in Xcode
open MagicMouseClick.xcodeproj

# Or build from command line
xcodebuild -scheme MagicMouseClick -configuration Release build
```

## Installation

1. Build the app (see above)
2. Copy `MagicMouseClick.app` to `/Applications`
3. Launch the app
4. Follow the setup wizard to grant Accessibility permission

## Usage

1. The app runs in the menu bar (no dock icon)
2. Click the menu bar icon to access settings
3. Enable/disable gestures with the toggle switch
4. Use the visualizer to confirm touch registration

## Configuration

- **Tap Duration**: How long a touch must last to register as a tap (100-350ms)
- **Movement Threshold**: Maximum finger movement allowed during a tap (0.01-0.10)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
