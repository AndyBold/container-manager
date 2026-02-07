# Claude Code Instructions for Container Manager

## Project Overview

This is a native macOS container management application built with SwiftUI. It supports Apple's container tool and provides both menu bar and desktop app modes.

## Code Style & Conventions

### SwiftUI Best Practices

#### Label Wrapping Prevention ⚠️ CRITICAL

**Always prevent label wrapping in horizontal layouts:**

When using SwiftUI controls with labels (Picker, Toggle, Button, etc.) in tight horizontal layouts, apply these modifiers:

```swift
// Segmented Picker Pattern
Picker("Label Text", selection: $binding) {
    ForEach(options) { option in
        Text(option).tag(option)
    }
}
.pickerStyle(.segmented)
.labelsHidden()  // Hide built-in label to prevent wrapping
.fixedSize()     // Prevent control compression
.frame(width: XXX) // Set explicit width

// Toggle Pattern
Toggle("Label Text", isOn: $binding)
    .toggleStyle(.switch)
    .fixedSize()  // Prevent label wrapping
    .help("Tooltip text")
```

**When to apply:**
- ✅ Segmented pickers in toolbars
- ✅ Toggles in horizontal layouts
- ✅ Any control in constrained horizontal space
- ✅ Controls where label might wrap to multiple lines

**Common locations:**
- Toolbar controls
- Inspector panels
- Settings views
- Modal headers

### Thread Safety & Performance

#### Background Processing

**Always run blocking operations on background threads:**

```swift
// ✅ Good - Non-blocking process execution
private func executeCommand() async -> String? {
    return await withCheckedContinuation { continuation in
        Task.detached {
            let process = Process()
            // ... setup process ...
            process.run()
            process.waitUntilExit()  // Blocks background thread only
            continuation.resume(returning: result)
        }
    }
}

// ❌ Bad - Blocks main thread
private func executeCommand() async -> String? {
    let process = Process()
    process.run()
    process.waitUntilExit()  // Blocks current thread!
    return result
}
```

**Thread-safe data access:**

```swift
// Use NSLock for simple synchronization
private let lock = NSLock()
nonisolated(unsafe) private var sharedData: [String: Data] = [:]

func updateData() {
    lock.lock()
    defer { lock.unlock() }
    // Safely access sharedData
}
```

### Naming Conventions

- **Views**: PascalCase (e.g., `ContainerListView`, `StatsView`)
- **Properties**: camelCase (e.g., `containerMonitor`, `isLoading`)
- **Methods**: camelCase with verb prefix (e.g., `startContainer`, `fetchLogs`)
- **Constants**: camelCase (e.g., `maxRetries`, `defaultTimeout`)

### File Organization

```
container-manager/
├── container-manager/           # Main app target
│   ├── *App.swift              # App entry point
│   ├── *SystemMonitor.swift    # Core business logic
│   ├── ContentView.swift       # Menu bar view
│   └── Assets.xcassets
├── Views/                       # UI components (root level)
│   ├── ContainerListView.swift
│   ├── StatsView.swift
│   └── ...
├── Tests/
└── docs/                        # All documentation
```

## Testing

### When to Write Tests

- New business logic in `ContainerSystemMonitor`
- Data models and parsers
- Network/Volume management features
- Complex algorithms (stats calculations, parsing)

### Testing Framework

Use the Testing framework (not XCTest) for new tests:

```swift
import Testing

@Test("Container stats parsing works correctly")
func testStatsParser() async throws {
    // Test implementation
}
```

## Git Commit Messages

Follow conventional commits format:

```
feat: implement stats collection for Apple container tool
fix: prevent label wrapping in stats view picker
docs: update architecture documentation
refactor: extract stats parsing to separate method
```

**Always include Co-Authored-By for AI assistance:**

```
feat: add detailed stats visualization

- Add enhanced charts with gradients
- Implement network I/O legend
- Add block I/O chart

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

## Common Patterns

### Stats Collection

- Collect every 10 seconds in background
- Store up to 6 hours of history (2160 data points)
- CPU calculated from cumulative microseconds delta
- All metrics thread-safe with NSLock

### Container Operations

```swift
// Pattern for container commands
private func performContainerOperation(command: String, containerName: String) async -> Bool {
    await MainActor.run { isOperating = true }
    defer { Task { await MainActor.run { isOperating = false } } }

    // Execute in background...
}
```

### View Modifiers

```swift
// Common modifier chain for cards
.padding()
.background(Color(nsColor: .controlBackgroundColor))
.cornerRadius(12)
```

## Dependencies

- macOS 14.0+
- SwiftUI with Charts framework
- Apple's `container` CLI tool
- No external package dependencies

## Documentation

All documentation lives in `docs/`:
- Architecture docs
- Phase summaries
- Development guides
- Test references

Keep README.md focused on getting started and features.

## Performance Guidelines

- Stats collection must not block UI (use Task.detached)
- Process execution must use background threads
- Published properties trigger UI updates - minimize changes
- Use `.chartXAxis(.hidden)` for compact charts to improve render performance

## Accessibility

- Always provide `.help()` tooltips for icon-only buttons
- Use SF Symbols for consistent iconography
- Ensure good contrast ratios
- Label all interactive elements

## Common Issues & Solutions

### Issue: Beachball/UI Freezing
**Solution:** Move `Process.waitUntilExit()` to `Task.detached`

### Issue: Label wrapping in pickers/toggles
**Solution:** Add `.labelsHidden()` and `.fixedSize()`

### Issue: Stats not updating
**Solution:** Check stats collection is running and publishing to @Published properties

### Issue: Memory leaks with closures
**Solution:** Use `[weak self]` in escaping closures and Tasks

---

**Last Updated:** 2026-02-07
**Project Phase:** Stats Visualization Complete
