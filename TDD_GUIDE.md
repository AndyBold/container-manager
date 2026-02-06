# TDD Test Guide - Phase 3

## Overview

We're taking a **Test-Driven Development (TDD)** approach for Phase 3 features. This means:

1. ✅ **Write tests first** (DONE)
2. 🔴 **Run tests** - They should fail (expected)
3. 🟢 **Implement features** to make tests pass
4. 🔵 **Refactor** code while keeping tests green

## Test Files Created

### 1. ContainerLogsTests.swift (440+ lines)
**Purpose**: Test container log viewing and streaming functionality

**Coverage**:
- ✅ Log parsing (simple, multi-line, with timestamps, with streams)
- ✅ Log streaming (fetch, tail, follow mode)
- ✅ Log filtering (by search term, by stream, by time range)
- ✅ Log export (to string, to file)
- ✅ Log buffer management (max size, ordering, clearing)
- ✅ Timestamp formatting and parsing
- ✅ Performance (parsing 1000+ entries, filtering 10K+ entries)

**Key Test Scenarios**:
```swift
@Test("Parse simple log line")
@Test("Fetch logs with tail limit")
@Test("Filter logs by search term")
@Test("Export logs to file")
@Test("Log buffer respects maximum size")
```

### 2. ContainerTerminalTests.swift (550+ lines)
**Purpose**: Test terminal/exec functionality for running commands in containers

**Coverage**:
- ✅ Command execution (simple, with arguments, with output capture)
- ✅ Interactive sessions (start, send input, receive output, terminate)
- ✅ Command history (storage, navigation, deduplication)
- ✅ Terminal buffer (output storage, ANSI codes, size limits)
- ✅ Shell detection (available shells, default shell)
- ✅ Working directory and environment variables
- ✅ Output streaming (real-time command output)
- ✅ Error handling (timeouts, non-running containers)
- ✅ Performance (concurrent command execution)

**Key Test Scenarios**:
```swift
@Test("Execute simple command in container")
@Test("Start interactive exec session")
@Test("Command history navigation works")
@Test("Terminal buffer handles ANSI escape codes")
@Test("Execute multiple commands concurrently")
```

### 3. ImageManagementTests.swift (650+ lines)
**Purpose**: Test image management operations (list, pull, push, remove, etc.)

**Coverage**:
- ✅ Image listing (fetch, parse, handle empty)
- ✅ Image pull (by name, with tag, with progress, from registry)
- ✅ Image push (to registry, with progress)
- ✅ Image removal (by ID, by name:tag, force remove, multiple)
- ✅ Image inspection (details, history, layers)
- ✅ Image search (in registry, with filters, empty results)
- ✅ Image tagging (new names, multiple tags)
- ✅ Image build (from Dockerfile, with progress)
- ✅ Image filtering (by repository, dangling, sorting)
- ✅ Image size calculation and parsing
- ✅ Image export/import (tar files)
- ✅ Registry authentication (login, logout)
- ✅ Performance (parse 1000+ images, filter 10K+)

**Key Test Scenarios**:
```swift
@Test("Fetch list of images")
@Test("Pull image with progress reporting")
@Test("Remove multiple images")
@Test("Search for images in registry")
@Test("Parse large image list efficiently")
```

## Running the Tests

### Run All Tests
```bash
# In Xcode
⌘U

# Or from command line
xcodebuild test -scheme container-manager

# Run specific test file
xcodebuild test -scheme container-manager -only-testing:container-managerTests/ContainerLogsTests

# Run specific test
xcodebuild test -scheme container-manager -only-testing:container-managerTests/ContainerLogsTests/parseSimpleLogLine
```

### Expected Initial State

**All tests should FAIL** 🔴 initially because:
- Functions return `nil` (stub implementations)
- No actual command execution
- Mock data structures in test files

This is **correct and expected** in TDD!

## Implementation Order

### Phase 3.1: Container Logs (Priority 1)

**Step 1: Implement LogEntry Model**
```swift
// Move from test file to actual implementation
struct LogEntry {
    // ... all the parsing and filtering methods
}
```

**Step 2: Add Logs Methods to ContainerSystemMonitor**
```swift
extension ContainerSystemMonitor {
    func fetchLogs(containerName: String, tail: Int) async -> [LogEntry]? {
        // Execute: container logs <name> --tail <N>
    }
    
    func streamLogs(containerName: String) async -> AsyncStream<LogEntry>? {
        // Execute: container logs <name> --follow
    }
}
```

**Step 3: Create ContainerLogsView**
```swift
struct ContainerLogsView: View {
    // UI implementation
}
```

**Tests to Pass**:
- ✅ All parsing tests
- ✅ Fetch logs tests
- ✅ Filtering tests
- ✅ Export tests

### Phase 3.2: Terminal/Exec (Priority 2)

**Step 1: Implement Exec Methods**
```swift
extension ContainerSystemMonitor {
    func execCommand(containerName: String, command: String, ...) async -> ExecResult? {
        // Execute: container exec <name> <command>
    }
}
```

**Step 2: Implement Interactive Session**
```swift
actor InteractiveExecSession {
    // PTY or Process management
    // Input/output handling
}
```

**Step 3: Create ContainerTerminalView**
```swift
struct ContainerTerminalView: View {
    // Terminal UI with input field and output display
}
```

**Tests to Pass**:
- ✅ Command execution tests
- ✅ Interactive session tests
- ✅ Command history tests
- ✅ Terminal buffer tests

### Phase 3.3: Image Management (Priority 3)

**Step 1: Implement Image Methods**
```swift
extension ContainerSystemMonitor {
    func fetchImages() async -> [ImageInfo]? {
        // Execute: container images
    }
    
    func pullImage(_ imageName: String, ...) async -> ImageOperationResult? {
        // Execute: container pull <image>
    }
    
    // ... other image operations
}
```

**Step 2: Enhance ImageListView**
```swift
// Replace stub in ImageListView.swift with real implementation
struct ImageListView: View {
    @State private var images: [ImageInfo] = []
    
    var body: some View {
        // Use real data from containerMonitor
    }
}
```

**Step 3: Add Image Operations UI**
```swift
// Pull dialog
// Remove confirmation
// Context menus
```

**Tests to Pass**:
- ✅ Image listing tests
- ✅ Pull/push tests
- ✅ Remove tests
- ✅ Filtering tests

## TDD Workflow

### For Each Feature:

**1. Red Phase 🔴**
```bash
# Run tests - they should fail
xcodebuild test -scheme container-manager -only-testing:ContainerLogsTests
# ❌ Tests fail (expected!)
```

**2. Green Phase 🟢**
```swift
// Implement minimum code to pass tests
func fetchLogs(containerName: String, tail: Int) async -> [LogEntry]? {
    // Implementation here
}
```
```bash
# Run tests again
xcodebuild test -scheme container-manager -only-testing:ContainerLogsTests
# ✅ Tests pass!
```

**3. Refactor Phase 🔵**
```swift
// Clean up code, improve performance, add comments
// Keep tests passing!
```

**4. Repeat**
Move to next test, repeat cycle.

## Test Coverage Goals

### Minimum Acceptable Coverage
- **Unit Tests**: 80%+ coverage
- **Integration Tests**: Key workflows covered
- **Edge Cases**: All error conditions tested

### Critical Areas
1. **Command Parsing**: Must handle all output formats
2. **Error Handling**: Graceful failures
3. **Performance**: No blocking operations on main thread
4. **Concurrency**: Thread-safe operations

## Mock Data vs Real Data

### Test Files Include Mock Structures

These are **temporary** and should be moved to real implementation files:

**From ContainerLogsTests.swift**:
- `LogEntry` struct
- `LogBuffer` struct

**From ContainerTerminalTests.swift**:
- `ExecResult` struct
- `InteractiveExecSession` actor
- `CommandHistory` struct
- `TerminalBuffer` struct

**From ImageManagementTests.swift**:
- `ImageInfo` struct
- `ImageOperationResult` struct
- `ImageProgress` struct
- `BuildProgress` struct
- `ImageDetails` struct
- And more...

### Migration Strategy

1. Create new files:
   - `ContainerLogs.swift`
   - `ContainerExec.swift`
   - `ImageManagement.swift`

2. Move structs/classes from test files to implementation files

3. Update test imports if needed

4. Remove mock implementations from test files

## Continuous Integration

### GitHub Actions Workflow (Future)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: xcodebuild test -scheme container-manager
      - name: Generate coverage
        run: xcodebuild test -scheme container-manager -enableCodeCoverage YES
```

## Best Practices

### Writing Tests

✅ **DO**:
- Write descriptive test names
- Test one thing per test
- Use `#expect` for assertions
- Test edge cases and errors
- Make tests independent
- Use async/await properly

❌ **DON'T**:
- Write tests that depend on order
- Use hardcoded timeouts (use Task.sleep with short durations)
- Test implementation details
- Leave commented-out code
- Skip error case testing

### Implementing Features

✅ **DO**:
- Start with simplest test
- Write minimal code to pass
- Refactor after tests pass
- Keep functions focused
- Handle errors gracefully
- Document complex logic

❌ **DON'T**:
- Implement features without tests
- Change multiple things at once
- Ignore failing tests
- Skip refactoring
- Over-engineer solutions

## Test Data

### Sample Container Logs
```
2026-02-06T10:30:45.123456Z stdout: Application starting...
2026-02-06T10:30:45.234567Z stdout: Configuration loaded
2026-02-06T10:30:45.345678Z stderr: Warning: Deprecated option used
2026-02-06T10:30:46.123456Z stdout: Server listening on port 8080
```

### Sample Image List Output
```
REPOSITORY              TAG       IMAGE ID       CREATED        SIZE
nginx                   latest    abcd1234       2 days ago     142MB
redis                   alpine    efgh5678       1 week ago     32MB
postgres                15        ijkl9012       3 weeks ago    379MB
<none>                  <none>    xyz789         1 month ago    100MB
```

### Sample Exec Output
```
total 24
drwxr-xr-x  6 root root 4096 Feb  6 10:30 .
drwxr-xr-x 14 root root 4096 Feb  6 10:29 ..
-rw-r--r--  1 root root  220 Feb  6 10:29 .bashrc
-rw-r--r--  1 root root  807 Feb  6 10:29 .profile
drwxr-xr-x  2 root root 4096 Feb  6 10:30 app
drwxr-xr-x  2 root root 4096 Feb  6 10:30 config
```

## Debugging Tips

### Test Not Failing When It Should
```swift
// Add temporary print statement
print("🔍 Result: \(result)")
#expect(result != nil)
```

### Async Test Timing Out
```swift
// Increase timeout or add sleep
try? await Task.sleep(for: .seconds(1))
```

### Test Failing Intermittently
```swift
// Check for race conditions
// Use actors for shared state
// Avoid Task.sleep for synchronization
```

## Next Steps

1. **Run Tests**: Execute all test suites to verify they fail appropriately
2. **Pick a Feature**: Start with Container Logs (simplest)
3. **Implement**: Write code to pass first test
4. **Iterate**: Continue until all tests pass
5. **UI Integration**: Connect to SwiftUI views
6. **Manual Testing**: Test in real app
7. **Documentation**: Update guides with actual usage

## Progress Tracking

### Container Logs
- [x] Tests written (27 tests)
- [ ] LogEntry model implemented
- [ ] Parsing logic implemented
- [ ] Command execution implemented
- [ ] UI created
- [ ] Integration complete

### Terminal/Exec
- [x] Tests written (25 tests)
- [ ] ExecResult model implemented
- [ ] Command execution implemented
- [ ] Interactive session implemented
- [ ] UI created
- [ ] Integration complete

### Image Management
- [x] Tests written (35 tests)
- [ ] ImageInfo model implemented
- [ ] List command implemented
- [ ] Pull command implemented
- [ ] Push command implemented
- [ ] Remove command implemented
- [ ] UI enhanced
- [ ] Integration complete

---

**Total Tests Written**: 87 tests  
**Total Test Code**: ~1,640 lines  
**Expected Initial Pass Rate**: 0% (all tests should fail initially)  
**Target Final Pass Rate**: 100%

Remember: **Failing tests at the start is SUCCESS in TDD!** 🎯

Let's make those tests pass! 🚀
