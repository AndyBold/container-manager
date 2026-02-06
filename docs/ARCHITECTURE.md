# Architecture Diagram

## Application Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│                    container_managerApp (@main)                     │
│                                                                     │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │
│  │  MenuBarExtra   │  │  Window Scene    │  │  Settings Scene  │ │
│  │   (Always On)   │  │  (On-Demand)     │  │   (On-Demand)    │ │
│  └────────┬────────┘  └─────────┬────────┘  └─────────┬────────┘ │
│           │                     │                      │           │
└───────────┼─────────────────────┼──────────────────────┼───────────┘
            │                     │                      │
            │    ┌────────────────┴──────────────────┐   │
            │    │  @EnvironmentObject Sharing       │   │
            │    │  ContainerSystemMonitor (Shared)  │   │
            │    └────────────────┬──────────────────┘   │
            ▼                     ▼                      ▼
    ┌───────────────┐    ┌────────────────┐    ┌────────────────┐
    │  ContentView  │    │ DesktopAppWindow│    │  SettingsView  │
    │  (Menu Bar)   │    │   (Desktop)     │    │ (Preferences)  │
    └───────────────┘    └────────────────┘    └────────────────┘
```

## Desktop Window Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                         DesktopAppWindow                               │
├──────────────────┬─────────────────────────────────────────────────────┤
│                  │                                                     │
│   Sidebar        │              DetailContentView                      │
│                  │                                                     │
│  ┌────────────┐  │  ┌────────────────────────────────────────────┐   │
│  │ Containers │──┼─→│ ContainerListView                          │   │
│  ├────────────┤  │  │  ├─ Table/Grid Toggle                      │   │
│  │ Images     │──┼─→│  ├─ Filter (All/Running/Stopped)           │   │
│  ├────────────┤  │  │  ├─ Sort (Name/Status/Created)             │   │
│  │ Volumes    │──┼─→│  ├─ Search Bar                             │   │
│  ├────────────┤  │  │  └─ HSplitView:                            │   │
│  │ Networks   │──┼─→│      ├─ List/Grid Content                  │   │
│  ├────────────┤  │  │      └─ ContainerInspectorView             │   │
│  │ Stats      │──┼─→│                                            │   │
│  ├────────────┤  │  └────────────────────────────────────────────┘   │
│  │ Settings   │──┼─→│ ImageListView                               │   │
│  └────────────┘  │  │ VolumeListView                              │   │
│                  │  │ NetworkListView                             │   │
│                  │  │ StatsView                                   │   │
│                  │  │ SettingsView                                │   │
└──────────────────┴─────────────────────────────────────────────────────┘
```

## Container List View Detail

```
┌────────────────────────────────────────────────────────────────────────┐
│  ContainerListView                                                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Toolbar: [Filter] [Sort] [View Mode] [Inspector Toggle]              │
│  ─────────────────────────────────────────────────────────────────────│
│                                                                        │
│  ┌─────────────────────────────────┐  ┌──────────────────────────┐  │
│  │                                 │  │  Inspector Panel         │  │
│  │  List View:                     │  │  ──────────────────────  │  │
│  │  ┌───────────────────────────┐  │  │  Overview:              │  │
│  │  │ Name    │ Status │ Ports  │  │  │   • Container Name      │  │
│  │  ├───────────────────────────┤  │  │   • Status              │  │
│  │  │ nginx   │ ✓ Run  │ 8080   │◀─┼─▶│   • Image               │  │
│  │  │ redis   │ ✗ Stop │ -      │  │  │                         │  │
│  │  │ postgres│ ✓ Run  │ 5432   │  │  │  Network:               │  │
│  │  └───────────────────────────┘  │  │   • Ports               │  │
│  │                                 │  │   • IP Address          │  │
│  │  Grid View:                     │  │                         │  │
│  │  ┌─────┐ ┌─────┐ ┌─────┐      │  │  Quick Actions:         │  │
│  │  │ ✓ 1 │ │ ✗ 2 │ │ ✓ 3 │      │  │   [View Logs]           │  │
│  │  │nginx│ │redis│ │post │      │  │   [Terminal]            │  │
│  │  └─────┘ └─────┘ └─────┘      │  │   [Files]               │  │
│  │                                 │  │                         │  │
│  └─────────────────────────────────┘  └──────────────────────────┘  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## State Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ContainerSystemMonitor                         │
│                     (Single Source of Truth)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  @Published Properties:                                             │
│   • status: ContainerSystemStatus                                   │
│   • containers: [ContainerInfo]                                     │
│   • lastUpdated: Date                                               │
│   • isOperating: Bool                                               │
│                                                                     │
│  Timer (10s) ──┐                                                    │
│                ▼                                                    │
│         checkContainerStatus()                                      │
│                │                                                    │
│                ├─→ Execute: container ls -a                         │
│                ├─→ Parse output                                     │
│                ├─→ Compare with current state                       │
│                └─→ Update @Published properties (if changed)        │
│                                                                     │
│  User Actions ───→ startContainer/stopContainer/etc.                │
│                    │                                                │
│                    ├─→ Set isOperating = true                       │
│                    ├─→ Execute command                              │
│                    ├─→ Wait for completion                          │
│                    ├─→ Refresh status                               │
│                    └─→ Set isOperating = false                      │
│                                                                     │
└─────┬───────────────────────────────────────────────────┬───────────┘
      │                                                   │
      │ @EnvironmentObject                                │ @EnvironmentObject
      ▼                                                   ▼
┌─────────────┐                                    ┌──────────────┐
│ ContentView │                                    │ Desktop Views│
│ (Menu Bar)  │                                    │  • List      │
│             │                                    │  • Inspector │
│  Observes:  │                                    │  • Stats     │
│  • status   │                                    │  • Settings  │
│  • contains │                                    │              │
│             │                                    │  All observe │
└─────────────┘                                    │  same state  │
                                                   └──────────────┘
```

## Component Interaction

```
User Actions Flow:
─────────────────

1. Right-Click Container
   │
   ▼
2. ContainerContextMenu displays
   │
   ▼
3. Select "Stop"
   │
   ▼
4. performAction() called
   │
   ├─→ Sets isOperating = true
   │   (Disables UI, pauses polling)
   │
   ├─→ Calls containerMonitor.stopContainer()
   │   │
   │   ├─→ Executes: container stop <name>
   │   │
   │   └─→ Waits for completion
   │
   ├─→ Refreshes container list
   │
   └─→ Sets isOperating = false
       (Re-enables UI, resumes polling)
   │
   ▼
5. UI automatically updates
   (Both menu bar and desktop window)
```

## Window Coordination

```
┌──────────────────────────────────────────────────────────────────┐
│                       App Delegate                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  applicationDidFinishLaunching:                                  │
│   └─→ NSApp.setActivationPolicy(.accessory)                      │
│       (Hide from Dock, show only menu bar)                       │
│                                                                  │
│  When Desktop Window Opens:                                      │
│   ├─→ NSApp.setActivationPolicy(.regular)                        │
│   │   (Show in Dock for window management)                       │
│   │                                                              │
│   └─→ Window appears, brings app to front                        │
│                                                                  │
│  When All Windows Close:                                         │
│   ├─→ NSApp.setActivationPolicy(.accessory)                      │
│   │   (Return to menu bar only)                                  │
│   │                                                              │
│   └─→ App continues running                                      │
│                                                                  │
│  Quit:                                                           │
│   └─→ NSApplication.shared.terminate()                           │
│       (Only via menu or ⌘Q, not window close)                    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Notification System

```
┌────────────────────────────────────────────────────────────────┐
│                    NotificationCenter                          │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Custom Notifications:                                         │
│                                                                │
│  .openDesktopWindow                                            │
│   • Posted by: ContentView (menu bar)                          │
│   • Received by: AppDelegate                                   │
│   • Action: Opens/focuses desktop window                       │
│                                                                │
│  .openContainerLogs                                            │
│   • Posted by: ContainerContextMenu                            │
│   • Payload: ["containerName": String]                         │
│   • Action: Opens log viewer (future implementation)           │
│                                                                │
│  .openContainerInspector                                       │
│   • Posted by: ContainerContextMenu                            │
│   • Payload: ["containerName": String]                         │
│   • Action: Opens inspector window                             │
│                                                                │
│  .openContainerTerminal                                        │
│   • Posted by: ContainerContextMenu                            │
│   • Payload: ["containerName": String]                         │
│   • Action: Opens terminal session (future implementation)     │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Data Models

```
┌────────────────────────────────────────────────────────────────┐
│                     Data Models                                │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ContainerSystemStatus (enum)                                  │
│   • running                                                    │
│   • stopped                                                    │
│   • error                                                      │
│                                                                │
│  ContainerInfo (struct)                                        │
│   • id: UUID                                                   │
│   • name: String                                               │
│   • status: String                                             │
│   • image: String?                                             │
│   • ports: String?                                             │
│   • created: String?                                           │
│                                                                │
│  SidebarSection (enum)                                         │
│   • containers                                                 │
│   • images                                                     │
│   • volumes                                                    │
│   • networks                                                   │
│   • stats                                                      │
│   • settings                                                   │
│                                                                │
│  ImageInfo (struct) - Future                                   │
│  VolumeInfo (struct) - Future                                  │
│  NetworkInfo (struct) - Future                                 │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Threading Model

```
┌────────────────────────────────────────────────────────────────┐
│                    Threading & Concurrency                     │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Main Thread (UI)                                              │
│   • All SwiftUI views                                          │
│   • @Published property updates                                │
│   • User interactions                                          │
│   • Window management                                          │
│                                                                │
│  Background (async/await)                                      │
│   • Container command execution                                │
│   • Output parsing                                             │
│   • File system operations                                     │
│   • Network requests (future)                                  │
│                                                                │
│  Timer Thread                                                  │
│   • Scheduled polling (every 10s)                              │
│   • Calls async checkContainerStatus()                         │
│   • Pauses during isOperating                                  │
│                                                                │
│  Actor Pattern (Future)                                        │
│   • ContainerMonitor as actor                                  │
│   • Thread-safe state mutations                                │
│   • Automatic synchronization                                  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Build & Distribution

```
┌────────────────────────────────────────────────────────────────┐
│                 Build Pipeline (Future)                        │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  1. Development                                                │
│     └─→ Xcode Build (⌘B)                                       │
│         └─→ Debug build for testing                            │
│                                                                │
│  2. Testing                                                    │
│     └─→ xcodebuild test (⌘U)                                   │
│         ├─→ Unit tests                                         │
│         ├─→ Integration tests                                  │
│         └─→ UI tests                                           │
│                                                                │
│  3. Archive                                                    │
│     └─→ Product → Archive                                      │
│         └─→ Optimized release build                            │
│                                                                │
│  4. Code Signing                                               │
│     └─→ Developer ID certificate                               │
│         └─→ Hardened runtime enabled                           │
│                                                                │
│  5. Notarization                                               │
│     └─→ xcrun notarytool                                       │
│         └─→ Apple verification                                 │
│                                                                │
│  6. Distribution                                               │
│     ├─→ Direct download (.dmg)                                 │
│     ├─→ Homebrew cask                                          │
│     ├─→ GitHub releases                                        │
│     └─→ Mac App Store (optional)                               │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

This architecture provides:
- Clear separation of concerns
- Scalable component structure
- Efficient state management
- Native macOS experience
- Easy extensibility
