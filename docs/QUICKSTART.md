# Quick Start Guide - Building Container Manager

## Prerequisites

- macOS 14.0 or later
- Xcode 16.0 or later
- Swift 5.9+
- Apple's container tool (or Docker/Podman)

## Setup

### 1. Clone and Open

```bash
git clone https://github.com/yourusername/container-manager.git
cd container-manager
open container-manager.xcodeproj
```

### 2. Build and Run

Press `⌘R` or click the Run button. The app will:
1. Start in menu bar (look for 📦 icon)
2. Begin monitoring containers automatically
3. Allow you to press `⌘M` to open desktop window

### 3. Verify Container Tool

Ensure the container command works:

```bash
which container
container ls -a
```

If using Docker or Podman, you may need to modify paths in `ContainerSystemMonitor.swift`.

## Project Tour

### Core Files (Start Here)

**1. `container_managerApp.swift`**
```swift
@main
struct container_managerApp: App {
    var body: some Scene {
        MenuBarExtra { ... }  // Menu bar mode
        Window { ... }         // Desktop mode
        Settings { ... }       // Preferences
    }
}
```
- Entry point for the app
- Defines all scenes (menu bar, desktop window, settings)
- Manages keyboard shortcuts
- Controls Dock visibility

**2. `ContainerSystemMonitor.swift`**
```swift
class ContainerSystemMonitor: ObservableObject {
    @Published var status: ContainerSystemStatus
    @Published var containers: [ContainerInfo]
    
    func checkContainerStatus() { ... }
    func startContainer(named:) async -> Bool { ... }
}
```
- Single source of truth for container state
- Shared across all views
- Executes container commands
- Parses output into models
- Manages polling timer

**3. `ContentView.swift`**
- Menu bar popup interface
- Compact list of containers
- Quick actions
- "Open Manager" button

**4. `DesktopAppWindow.swift`**
- Main desktop window shell
- Sidebar navigation
- Toolbar with search and status
- Routes to detail views

### Desktop App Views

**ContainerListView.swift** - Full container management
- Table/grid view modes
- Filtering and sorting
- Search functionality
- Inspector panel integration

**ContainerInspectorView.swift** - Detail panel
- Selected container info
- Quick actions
- Resource usage (placeholder)

**ContainerActions.swift** - Reusable components
- Context menus
- Action menus
- Confirmation dialogs

**ImageListView.swift** - Image management (stub)
**VolumeListView.swift** - Volume management (stub)
**NetworkListView.swift** - Network management (stub)
**StatsView.swift** - Statistics dashboard (placeholder)
**SettingsView.swift** - App preferences

## Adding Your First Feature

Let's add a "pause" action to containers!

### Step 1: Add Command to Monitor

**ContainerSystemMonitor.swift:**
```swift
func pauseContainer(named name: String) async -> Bool {
    return await performContainerOperation(
        command: "pause",
        containerName: name
    )
}

func unpauseContainer(named name: String) async -> Bool {
    return await performContainerOperation(
        command: "unpause",
        containerName: name
    )
}
```

### Step 2: Add to Context Menu

**ContainerActions.swift:**
```swift
struct ContainerContextMenu: View {
    var body: some View {
        // ... existing code ...
        
        if isRunning {
            Button(action: { 
                performAction { 
                    await containerMonitor.pauseContainer(named: container.name) 
                }
            }) {
                Label("Pause", systemImage: "pause.fill")
            }
        }
    }
}
```

### Step 3: Update Status Detection

**ContainerSystemMonitor.swift:**
```swift
// Add "paused" to status parsing
private var isRunning: Bool {
    let status = container.status.lowercased()
    return status == "running" || status == "up"
}

private var isPaused: Bool {
    let status = container.status.lowercased()
    return status == "paused"
}
```

### Step 4: Test

1. Run the app
2. Find a running container
3. Right-click and select "Pause"
4. Verify status updates

## Common Tasks

### Adding a New Sidebar Section

**1. Define the section:**
```swift
// DesktopAppWindow.swift
enum SidebarSection: String, CaseIterable {
    case mySection = "My Section"
    
    var icon: String {
        case .mySection: return "star.fill"
    }
}
```

**2. Create the view:**
```swift
// MySection.swift
struct MySectionView: View {
    let searchText: String
    
    var body: some View {
        VStack {
            Text("My Section Content")
        }
    }
}
```

**3. Wire it up:**
```swift
// DesktopAppWindow.swift - DetailContentView
switch section {
case .mySection:
    MySectionView(searchText: searchText)
}
```

### Adding a New Container Property

**1. Update the model:**
```swift
// ContainerSystemMonitor.swift
struct ContainerInfo {
    let name: String
    let status: String
    let myNewProperty: String?  // Add this
}
```

**2. Parse it:**
```swift
// ContainerSystemMonitor.swift - parseContainerOutput
let myValue = components.count > indexX ? components[indexX] : nil
newContainers.append(ContainerInfo(
    name: name,
    status: status,
    myNewProperty: myValue
))
```

**3. Display it:**
```swift
// ContainerInspectorView.swift
if let value = container.myNewProperty {
    InspectorRow(label: "My Property", value: value)
}
```

### Adding a Setting

**1. Define storage:**
```swift
// SettingsView.swift
@AppStorage("mySetting") private var mySetting = false
```

**2. Add UI:**
```swift
Section("My Settings") {
    Toggle("Enable my feature", isOn: $mySetting)
        .help("Description of what this does")
}
```

**3. Use it:**
```swift
// Any View
@AppStorage("mySetting") private var mySetting = false

if mySetting {
    // Feature enabled
}
```

## Debugging Tips

### Enable Verbose Logging

Add print statements in `ContainerSystemMonitor`:
```swift
func checkContainerStatus() {
    print("🔍 Checking container status...")
    // ... code ...
    print("✅ Found \(containers.count) containers")
}
```

### Inspect Container Command Output

```swift
private func checkAppleContainerStatus() async {
    // ... existing code ...
    if let output = String(data: data, encoding: .utf8) {
        print("📄 Raw output:\n\(output)")
        // ... parsing ...
    }
}
```

### Monitor State Changes

```swift
.onChange(of: containerMonitor.containers) { oldValue, newValue in
    print("📦 Containers changed: \(oldValue.count) -> \(newValue.count)")
}
```

### Check Window Lifecycle

```swift
// AppDelegate
func applicationDidFinishLaunching(_ notification: Notification) {
    print("🚀 App launched")
    print("📍 Activation policy: \(NSApp.activationPolicy())")
}
```

## Testing

### Run All Tests
```bash
⌘U
# Or from terminal:
xcodebuild test -scheme container-manager
```

### Write a New Test

**ContainerSystemMonitorTests.swift:**
```swift
@Test("Pause container operation")
func testPauseContainer() async throws {
    let monitor = ContainerSystemMonitor()
    
    // Mock a running container
    monitor.containers = [
        ContainerInfo(name: "test", status: "running")
    ]
    
    // Attempt to pause
    let success = await monitor.pauseContainer(named: "test")
    
    #expect(success == true)
}
```

## Performance Optimization

### Reduce Refresh Interval

```swift
// ContainerSystemMonitor.swift
timer = Timer.scheduledTimer(
    withTimeInterval: 5.0,  // Changed from 10.0
    repeats: true
) { ... }
```

### Debounce Search

```swift
// ContainerListView.swift
@State private var searchDebounce: Task<Void, Never>?

var body: some View {
    TextField("Search", text: $searchText)
        .onChange(of: searchText) { oldValue, newValue in
            searchDebounce?.cancel()
            searchDebounce = Task {
                try? await Task.sleep(for: .milliseconds(300))
                // Perform search
            }
        }
}
```

### Lazy Load Container Details

```swift
// ContainerDetailView.swift
var body: some View {
    ScrollView {
        LazyVStack {
            ForEach(containers) { container in
                ContainerRow(container: container)
            }
        }
    }
}
```

## Distribution

### Archive for Distribution

1. Product → Archive
2. Distribute App
3. Choose distribution method:
   - Direct Distribution (for personal use)
   - Mac App Store (requires Apple Developer Program)
   - Developer ID (for distribution outside App Store)

### Code Signing

For distribution outside the App Store, you'll need:
1. Apple Developer account
2. Developer ID certificate
3. Notarization

```bash
# Notarize the app
xcrun notarytool submit container-manager.zip \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "app-specific-password"
```

### Sparkle for Auto-Updates

Add [Sparkle](https://sparkle-project.org) for automatic updates:

```swift
import Sparkle

@main
struct container_managerApp: App {
    @StateObject private var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
}
```

## Next Steps

1. **Explore the Code**: Read through each file to understand the architecture
2. **Make Small Changes**: Try modifying UI colors, icons, or text
3. **Add Features**: Implement one of the planned features from the roadmap
4. **Contribute**: Submit pull requests with improvements
5. **Share**: Show off what you've built!

## Resources

- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [AppKit Documentation](https://developer.apple.com/documentation/appkit)
- [Container Manager Issues](https://github.com/yourusername/container-manager/issues)
- [Swift Forums](https://forums.swift.org)

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/yourusername/container-manager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/container-manager/discussions)
- **Email**: your@email.com

---

Happy coding! 🚀
