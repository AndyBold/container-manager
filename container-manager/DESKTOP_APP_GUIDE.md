# Desktop App Enhancement - Implementation Guide

## Overview

This guide documents the new full desktop application that extends your menu bar container manager into a comprehensive container management platform similar to OrbStack, Docker Desktop, and Podman Desktop.

## Architecture

### Dual-Mode Application

The app now operates in **two modes simultaneously**:

1. **Menu Bar Mode** (Always Available)
   - Lightweight, quick access from menu bar
   - Status monitoring and basic operations
   - Hidden from Dock and App Switcher

2. **Desktop App Mode** (On-Demand)
   - Full-featured management interface
   - Multi-section sidebar navigation
   - Comprehensive container, image, volume, and network management
   - Real-time statistics and monitoring

### File Structure

```
container-manager/
├── container_managerApp.swift          # Main app with dual scenes
├── ContentView.swift                   # Menu bar popup (enhanced)
├── ContainerSystemMonitor.swift        # Shared business logic
│
├── Desktop App/
│   ├── DesktopAppWindow.swift         # Main desktop window
│   ├── ContainerListView.swift        # Enhanced container list
│   ├── ContainerInspectorView.swift   # Detail inspector panel
│   ├── ContainerActions.swift         # Reusable action components
│   ├── ImageListView.swift            # Image management
│   ├── VolumeListView.swift           # Volume management
│   ├── NetworkListView.swift          # Network management
│   ├── StatsView.swift                # Statistics & monitoring
│   └── SettingsView.swift             # App preferences
│
└── Assets.xcassets/
```

## Key Features

### 1. Enhanced Navigation

**Sidebar Sections:**
- 🚢 **Containers** - Full container management with list/grid views
- 📦 **Images** - Image management (pull, push, remove)
- 💾 **Volumes** - Volume creation and management
- 🌐 **Networks** - Network configuration
- 📊 **Stats** - Real-time monitoring and charts
- ⚙️ **Settings** - Application preferences

### 2. Container Management

**View Modes:**
- **List View** - Table with sortable columns
- **Grid View** - Card-based layout with hover effects

**Filters & Sorting:**
- Filter by status (All, Running, Stopped)
- Sort by name, status, or creation date
- Live search across container names and images

**Actions:**
- Start/Stop/Restart containers
- View logs (coming soon)
- Open terminal/exec session (coming soon)
- Inspect container details
- Copy container information
- Remove containers with confirmation
- Batch operations on multiple containers

### 3. Inspector Panel

**Real-time Details:**
- Container overview (name, status, image)
- Network information (ports, addresses)
- Resource usage (CPU, memory)
- Quick action buttons
- Copy-to-clipboard functionality

### 4. Statistics Dashboard

**System Overview Cards:**
- Total container count
- System-wide CPU usage
- Total memory consumption
- Network I/O statistics

**Per-Container Stats:**
- Individual CPU usage charts
- Memory consumption over time
- Network traffic graphs
- Configurable time ranges (5m, 15m, 30m, 1h, 6h)

### 5. Settings & Preferences

**Configurable Options:**
- Auto-start container service
- Refresh interval
- Notification preferences
- Custom container tool path
- Default view modes
- Verbose logging

## Usage

### Opening the Desktop Window

**From Menu Bar:**
1. Click the shipping box icon in menu bar
2. Click "Open Manager" button
3. Or press `⌘M`

**From Menu:**
1. Click app name in menu bar
2. Select "Open Manager Window"
3. Or press `⌘M` (global shortcut)

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Manager Window | `⌘M` |
| Refresh Status | `⌘R` |
| Start/Stop Service | `⌘⇧S` |
| Search | `⌘F` |
| Quit | `⌘Q` |
| Settings | `⌘,` |

### Window Behavior

- **Menu Bar Always Available**: The menu bar icon remains visible even when the desktop window is open
- **Auto-Hide Dock Icon**: App only appears in Dock when desktop window is open
- **Window Persistence**: Desktop window state is preserved between launches
- **Multi-Window Support**: Can have multiple inspector/log windows open simultaneously

## Implementation Details

### State Management

**Shared State:**
- Single `ContainerSystemMonitor` instance shared across all views
- Real-time updates propagate to both menu bar and desktop windows
- Synchronized refresh intervals

**Window Coordination:**
```swift
// App switches between accessory and regular mode
NSApp.setActivationPolicy(.accessory)  // Menu bar only
NSApp.setActivationPolicy(.regular)    // Show in Dock
```

### Notifications

**Custom Notifications:**
```swift
.openDesktopWindow       // Open/focus desktop window
.openContainerLogs       // Open logs for specific container
.openContainerInspector  // Open inspector for container
.openContainerTerminal   // Open terminal for container
```

### Performance Optimizations

1. **Lazy Loading**: Container details loaded on-demand
2. **Efficient Updates**: Only refresh when data changes
3. **Smart Polling**: Pauses during user interactions
4. **View Recycling**: Table/Grid views recycle cells

## Extending the App

### Adding New Features

**1. Add New Sidebar Section:**

```swift
enum SidebarSection {
    case myNewSection
    
    var icon: String {
        case .myNewSection: return "star.fill"
    }
}
```

**2. Create View:**

```swift
struct MyNewSectionView: View {
    let searchText: String
    
    var body: some View {
        // Your implementation
    }
}
```

**3. Register in DetailContentView:**

```swift
switch section {
case .myNewSection:
    MyNewSectionView(searchText: searchText)
}
```

### Adding Container Operations

**1. Add to ContainerSystemMonitor:**

```swift
func myOperation(named name: String) async -> Bool {
    return await performContainerOperation(
        command: "mycommand",
        containerName: name
    )
}
```

**2. Add to Context Menu:**

```swift
Button("My Action") {
    performAction {
        await containerMonitor.myOperation(named: container.name)
    }
}
```

## Future Enhancements

### Phase 2 (Next Release)
- [ ] Container log viewer with live streaming
- [ ] Terminal/exec integration with PTY support
- [ ] Image pull/push with progress indicators
- [ ] Container creation wizard
- [ ] Volume browser with file navigation

### Phase 3
- [ ] Compose file support
- [ ] Multi-host/remote container management
- [ ] Advanced stats with historical data
- [ ] Custom action scripts
- [ ] Notification center integration

### Phase 4
- [ ] Docker/Podman compatibility layer
- [ ] Cloud registry integration
- [ ] Team collaboration features
- [ ] Advanced networking tools
- [ ] Kubernetes integration

## Testing

### Manual Testing Checklist

**Menu Bar:**
- [ ] Icon shows correct status color
- [ ] Quick actions work (start/stop/restart/remove)
- [ ] "Open Manager" button opens desktop window
- [ ] Keyboard shortcuts function correctly

**Desktop Window:**
- [ ] Window opens and focuses properly
- [ ] Sidebar navigation switches sections
- [ ] Container list displays correctly (list & grid)
- [ ] Filter and sort work as expected
- [ ] Inspector panel shows selected container
- [ ] Search filters containers
- [ ] Context menus appear correctly
- [ ] Settings persist between launches

**Cross-Window:**
- [ ] Changes in menu bar reflect in desktop window
- [ ] Changes in desktop window reflect in menu bar
- [ ] Multiple container operations don't conflict
- [ ] Window closing doesn't quit the app

### Unit Testing

Run tests:
```bash
xcodebuild test -scheme container-manager
```

Key test coverage:
- Container parsing from multiple formats
- State synchronization
- Action execution and rollback
- Error handling

## Troubleshooting

### Desktop Window Won't Open

**Solution 1: Reset Window State**
```bash
defaults delete com.yourcompany.container-manager
```

**Solution 2: Check Activation Policy**
Ensure `AppDelegate` properly manages `NSApp.setActivationPolicy()`

### Slow Performance

**Check:**
1. Reduce refresh interval in Settings
2. Disable verbose logging
3. Close unused inspector windows
4. Limit visible containers with filters

### UI Not Updating

**Verify:**
1. `@EnvironmentObject` properly injected
2. `@Published` properties used in `ContainerSystemMonitor`
3. Main actor updates for UI changes
4. No blocking operations on main thread

## Contributing

When adding features:

1. **Follow SwiftUI Best Practices**
   - Use `@State` for view-local state
   - Use `@EnvironmentObject` for shared state
   - Keep views focused and composable

2. **Maintain Consistency**
   - Match existing visual style
   - Use SF Symbols for icons
   - Follow naming conventions

3. **Test Thoroughly**
   - Test both menu bar and desktop modes
   - Verify state synchronization
   - Check error cases

4. **Document Changes**
   - Update README
   - Add inline comments for complex logic
   - Update keyboard shortcut list

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [AppKit Integration](https://developer.apple.com/documentation/appkit)
- [Menu Bar Extras](https://developer.apple.com/documentation/swiftui/menubarextra)
- [SF Symbols](https://developer.apple.com/sf-symbols/)

---

**Version:** 2.0.0  
**Last Updated:** February 2026
