# Test Execution Quick Reference

## 🚀 Quick Start

```bash
# Run all tests in Xcode
⌘U

# Or from terminal
xcodebuild test -scheme container-manager
```

## 📋 Test Files

| File | Tests | Lines | Coverage |
|------|-------|-------|----------|
| `ContainerLogsTests.swift` | 27 | 440+ | Log parsing, streaming, filtering, export |
| `ContainerTerminalTests.swift` | 25 | 550+ | Command exec, interactive sessions, history |
| `ImageManagementTests.swift` | 35 | 650+ | Image list, pull, push, remove, search |
| **Total** | **87** | **1,640+** | **Phase 3 Core Features** |

## 🎯 Run Specific Tests

### By File
```bash
# Container Logs Tests
xcodebuild test -scheme container-manager \
  -only-testing:container-managerTests/ContainerLogsTests

# Terminal Tests
xcodebuild test -scheme container-manager \
  -only-testing:container-managerTests/ContainerTerminalTests

# Image Management Tests
xcodebuild test -scheme container-manager \
  -only-testing:container-managerTests/ImageManagementTests
```

### By Individual Test
```bash
# Run single test
xcodebuild test -scheme container-manager \
  -only-testing:container-managerTests/ContainerLogsTests/parseSimpleLogLine

# Run multiple specific tests
xcodebuild test -scheme container-manager \
  -only-testing:container-managerTests/ContainerLogsTests/parseSimpleLogLine \
  -only-testing:container-managerTests/ContainerLogsTests/fetchLogsFromContainer
```

### In Xcode
1. Open Test Navigator (`⌘6`)
2. Click on test file or individual test
3. Click the ▶️ icon next to the test
4. Or right-click and select "Run"

## 📊 Expected Results

### Initial State (Before Implementation) 🔴
```
Test Suite 'ContainerLogsTests' started
❌ Test Case 'parseSimpleLogLine' failed
❌ Test Case 'fetchLogsFromContainer' failed
...
Test Suite 'ContainerLogsTests' failed
  Executed 27 tests, with 27 failures
```

**This is CORRECT!** Tests should fail before implementation in TDD.

### After Implementation 🟢
```
Test Suite 'ContainerLogsTests' started
✅ Test Case 'parseSimpleLogLine' passed (0.001 seconds)
✅ Test Case 'fetchLogsFromContainer' passed (0.015 seconds)
...
Test Suite 'ContainerLogsTests' passed
  Executed 27 tests, with 0 failures (0.234 seconds)
```

## 🔍 Test Categories

### Container Logs (27 tests)
- **Parsing**: 5 tests - Basic log line parsing, multiline, malformed
- **Streaming**: 4 tests - Fetch, tail, follow mode, non-existent container
- **Filtering**: 3 tests - Search term, stream type, time range
- **Export**: 2 tests - To string, to file
- **Buffer**: 3 tests - Max size, ordering, clearing
- **Timestamp**: 3 tests - Default format, custom format, ISO8601 parsing
- **Performance**: 2 tests - Parse 1000+ entries, filter 10K+ entries

### Terminal/Exec (25 tests)
- **Execution**: 5 tests - Simple, with args, stdout, stderr, failures
- **Interactive**: 4 tests - Start session, send input, receive output, terminate
- **History**: 5 tests - Storage, navigation, max size, deduplication, clearing
- **Buffer**: 4 tests - Storage, ANSI codes, max size, clearing
- **Shell**: 2 tests - Detect shells, default shell
- **Advanced**: 2 tests - Working directory, environment variables
- **Security**: 1 test - Execute as specific user
- **Streaming**: 1 test - Real-time output
- **Errors**: 2 tests - Timeout, not running
- **Performance**: 1 test - Concurrent execution

### Image Management (35 tests)
- **Listing**: 5 tests - Fetch, parse, no tag, dangling, empty
- **Pull**: 5 tests - By name, with tag, progress, non-existent, registry
- **Push**: 2 tests - To registry, with progress
- **Remove**: 5 tests - By ID, by name:tag, force, in use, multiple
- **Inspect**: 3 tests - Details, history, layers
- **Search**: 3 tests - Registry, filters, empty results
- **Tag**: 2 tests - New name, multiple tags
- **Build**: 2 tests - From Dockerfile, with progress
- **Filter**: 3 tests - By repository, dangling, sort
- **Size**: 2 tests - Parse string, calculate total
- **Export/Import**: 2 tests - To tar, from tar
- **Auth**: 2 tests - Login, logout
- **Performance**: 2 tests - Parse 1000+ images, filter 10K+

## 🐛 Debugging Failed Tests

### View Detailed Output
```bash
# Verbose test output
xcodebuild test -scheme container-manager \
  -only-testing:container-managerTests/ContainerLogsTests \
  | xcpretty --test

# Without xcpretty (raw output)
xcodebuild test -scheme container-manager \
  -only-testing:container-managerTests/ContainerLogsTests
```

### In Xcode
1. Run test
2. Click on failed test in Test Navigator
3. View failure details in Report Navigator (`⌘9`)
4. Check console output for print statements

### Add Debug Output
```swift
@Test("My test")
func myTest() async throws {
    print("🔍 Debug: value = \(value)")
    #expect(value == expectedValue)
}
```

## 📈 Code Coverage

### Generate Coverage Report
```bash
# Run tests with coverage
xcodebuild test -scheme container-manager \
  -enableCodeCoverage YES

# View in Xcode
# Product → Show Build Folder
# Open Coverage tab in Report Navigator
```

### Coverage Goals
- **Target**: 80%+ code coverage
- **Critical Paths**: 100% coverage for:
  - Parsing logic
  - Command execution
  - Error handling

## ⚡ Performance Benchmarking

### Performance Tests Included
```swift
@Test("Parse large number of log entries efficiently")
// Expectation: Parse 1000 entries in < 1 second

@Test("Filter large log set efficiently")
// Expectation: Filter 10K entries in < 0.5 seconds

@Test("Execute multiple commands concurrently")
// Expectation: Run 3 commands in < 3 seconds (concurrent, not sequential)
```

### Monitor Performance
```bash
# Run with instruments
xcodebuild test -scheme container-manager \
  -enableCodeCoverage YES \
  | grep "seconds"
```

## 🔄 Continuous Testing

### Watch Mode (using `fswatch`)
```bash
# Install fswatch
brew install fswatch

# Watch for changes and run tests
fswatch -o . | xargs -n1 -I{} \
  xcodebuild test -scheme container-manager
```

### Pre-commit Hook
```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running tests..."
xcodebuild test -scheme container-manager

if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Commit aborted."
  exit 1
fi

echo "✅ Tests passed. Committing..."
```

## 📝 Test Status Summary

### Current Status
```
┌─────────────────────────────────────────────┐
│           Test Suite Status                 │
├─────────────────────────────────────────────┤
│ ContainerLogsTests:        ⚪ Not Run       │
│ ContainerTerminalTests:    ⚪ Not Run       │
│ ImageManagementTests:      ⚪ Not Run       │
├─────────────────────────────────────────────┤
│ Total Tests:               87               │
│ Expected Failures:         87 (TDD Red)     │
│ Implementation Progress:   0%               │
└─────────────────────────────────────────────┘
```

### After First Feature (Logs)
```
┌─────────────────────────────────────────────┐
│           Test Suite Status                 │
├─────────────────────────────────────────────┤
│ ContainerLogsTests:        ✅ 27/27 Pass    │
│ ContainerTerminalTests:    ⚪ Not Run       │
│ ImageManagementTests:      ⚪ Not Run       │
├─────────────────────────────────────────────┤
│ Total Tests:               87               │
│ Passing:                   27 (31%)         │
│ Implementation Progress:   33%              │
└─────────────────────────────────────────────┘
```

### Target: All Features Complete
```
┌─────────────────────────────────────────────┐
│           Test Suite Status                 │
├─────────────────────────────────────────────┤
│ ContainerLogsTests:        ✅ 27/27 Pass    │
│ ContainerTerminalTests:    ✅ 25/25 Pass    │
│ ImageManagementTests:      ✅ 35/35 Pass    │
├─────────────────────────────────────────────┤
│ Total Tests:               87               │
│ Passing:                   87 (100%)        │
│ Implementation Progress:   100%             │
└─────────────────────────────────────────────┘
```

## 🎓 Best Practices

### ✅ Do
- Run tests before committing
- Keep tests running fast (< 1s per test)
- Write tests before implementation (TDD)
- Fix failing tests immediately
- Review test coverage regularly

### ❌ Don't
- Commit with failing tests
- Skip tests to make build faster
- Comment out failing tests
- Write tests after implementation
- Ignore performance test warnings

## 📚 Resources

- **TDD Guide**: See `TDD_GUIDE.md` for detailed methodology
- **Architecture**: See `ARCHITECTURE.md` for system design
- **Implementation**: See `DESKTOP_APP_GUIDE.md` for feature details
- **Checklist**: See `CHECKLIST.md` for progress tracking

## 🚀 Next Steps

1. **Run Initial Tests**: Verify all 87 tests fail (TDD red phase)
   ```bash
   xcodebuild test -scheme container-manager
   ```

2. **Choose First Feature**: Start with Container Logs (simplest)

3. **Make First Test Pass**: Implement `LogEntry.parse()` 
   ```swift
   @Test("Parse simple log line")
   func parseSimpleLogLine() async throws {
       // This test should now pass!
   }
   ```

4. **Iterate**: Continue until all tests green

5. **Celebrate**: 🎉 All tests passing means Phase 3 is complete!

---

**Last Updated**: February 2026  
**Test Coverage**: Phase 3 Core Features  
**Status**: Ready for Implementation (TDD Red Phase)
