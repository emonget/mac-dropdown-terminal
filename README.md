# DropdownTerminal

A macOS menu bar application that provides Guake-style terminal toggling functionality. Toggle any configurable application (defaulting to Terminal.app) with a single click, featuring visual state feedback and persistent settings.

## Features

- **Menu Bar Integration**: Single menu bar button for easy access
- **Configurable Applications**: Choose any application to toggle (defaults to Terminal.app)
- **Visual State Feedback**: Icon changes to reflect application visibility state
- **Right-Click Configuration**: Easy access to settings via right-click menu
- **Persistent Settings**: Remembers your app selection between sessions
- **Guake-Style Toggle**: Show/hide functionality similar to Guake terminal
- **Current Desktop Focus**: Brings apps to your current desktop/space instead of switching desktops

## Installation

### From Release (Recommended)

1. Download the latest `DropdownTerminal.dmg` from the [Releases](https://github.com/YOUR_USERNAME/mac-dropdown-terminal/releases) page
2. Mount the DMG and drag DropdownTerminal.app to your Applications folder
3. Launch DropdownTerminal from Applications
4. The app will appear in your menu bar

### Building from Source

Requirements:
- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.0 or later

```bash
git clone https://github.com/YOUR_USERNAME/mac-dropdown-terminal.git
cd mac-dropdown-terminal
open DropdownTerminal.xcodeproj
```

Build and run from Xcode, or use the command line:

```bash
xcodebuild -project DropdownTerminal.xcodeproj -scheme DropdownTerminal -configuration Release build
```

## Usage

### Basic Operation

1. **Left Click**: Toggle the configured application's visibility
2. **Right Click**: Access configuration menu

### Configuration

1. Right-click the menu bar icon
2. Select "Select App"
3. Enter the name of the application you want to toggle
4. Click "Save"

### Supported Applications

The app works with any macOS application, including:
- Terminal (default)
- iTerm2
- Hyper
- Alacritty
- Any other application installed on your system

## Visual Indicators

- **Inactive State**: Terminal icon (app is hidden)
- **Active State**: Terminal with plus badge (app is visible)

## Development

### Project Structure

```
DropdownTerminal/
├── DropdownTerminal.xcodeproj/    # Xcode project
├── DropdownTerminal/              # Source code
│   ├── AppDelegate.swift          # Main application delegate
│   ├── MenuBarController.swift    # Menu bar logic and app toggling
│   ├── SettingsManager.swift      # Persistent settings management
│   ├── Assets.xcassets/          # App icons and assets
│   └── Info.plist                # App configuration
├── .github/workflows/            # CI/CD pipeline
└── exportOptions.plist           # Build export settings
```

### Key Components

- **AppDelegate**: Main application entry point and lifecycle management
- **MenuBarController**: Handles menu bar UI, click events, and application toggling
- **SettingsManager**: Manages persistent storage of user preferences

### Building

The project includes a GitHub Actions workflow that automatically:
- Builds the application on every push/PR
- Creates DMG files for distribution
- Uploads release assets on tagged releases

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on macOS
5. Submit a pull request

## Requirements

- **System**: macOS 13.0 or later
- **Permissions**: The app requires accessibility permissions to control other applications
- **Architecture**: Universal binary (Intel and Apple Silicon)

## Permissions

DropdownTerminal requires specific permissions to function properly:

### Accessibility Permissions
On first launch, macOS will prompt for accessibility permissions. To manually grant:

1. Go to System Preferences → Security & Privacy → Privacy
2. Select "Accessibility" from the left sidebar
3. Click the lock to make changes
4. Add DropdownTerminal to the list of allowed applications

### Important Notes
- The app uses private macOS APIs to move windows between desktops/spaces
- This ensures apps appear on your current desktop rather than switching you to their desktop
- The app is not sandboxed to enable this functionality
- Future macOS updates may affect compatibility due to private API usage

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [Guake Terminal](http://guake-project.org/) for Linux
- Built with Swift and Cocoa frameworks
- Uses SF Symbols for menu bar icons

## Roadmap

- [ ] Global hotkey support
- [ ] Multiple application profiles
- [ ] Window positioning preferences
- [ ] Launch at login option
- [ ] Custom menu bar icons

## Support

If you encounter any issues or have feature requests, please [open an issue](https://github.com/YOUR_USERNAME/mac-dropdown-terminal/issues) on GitHub.