# Changelog

All notable changes to Container Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-08

### Added
- **Container Creation Wizard**: 7-step guided process for creating new containers
  - Image selection with search and custom image support
  - Basic configuration (name, command)
  - Port mapping configuration
  - Volume mount setup
  - Environment variable management
  - Network configuration
  - Configuration review and confirmation
- **Batch Operations**: Multi-select containers for bulk operations
  - Select multiple containers with checkboxes
  - Bulk start, stop, restart, or remove
  - Batch actions toolbar with operation buttons
- **Enhanced Statistics Dashboard**: Real-time monitoring with live charts
  - CPU usage tracking with delta calculations
  - Memory usage visualization
  - Network I/O monitoring (sent/received)
  - Disk I/O tracking (read/write)
  - Time range selection (1 minute to 1 hour)
  - Historical data collection (up to 6 hours)
- **Code Signing and Release Infrastructure**
  - Developer ID Application signing
  - Hardened runtime support
  - DMG signing with timestamps
  - Notarization workflow with Apple
  - Automated verification scripts
  - Complete signing documentation
- **Animation Preferences**: Accessibility-aware animation controls
  - Master animation toggle
  - Reduce motion support (app and system)
  - Configurable loading indicators
  - Compact mode for reduced spacing
  - Automatic macOS accessibility integration

### Changed
- Improved stats collection efficiency with background processing
- Enhanced container list with better multi-select UX
- Updated build system with signed and unsigned build targets
- Simplified CI/CD to build validation only

### Fixed
- Stats collection no longer blocks UI thread
- Container creation properly handles custom image names
- Removed unsupported options for Apple's container tool
- Better error messages for container operations
- UI tests no longer require code signing in CI

### Documentation
- Added `SIGNED_RELEASE_GUIDE.md` - Complete signing and notarization guide
- Added `docs/CODE_SIGNING_GUIDE.md` - Technical reference for code signing
- Updated `README.md` with new features and version 1.1.0
- Enhanced Makefile with comprehensive help and new targets
- Created `CHANGELOG.md` for version history tracking

## [1.0.0] - 2026-01-XX

### Added
- Initial release with full desktop application
- Menu bar mode for lightweight monitoring
- Desktop app mode for comprehensive management
- Real-time container monitoring
- Container operations (start, stop, restart, remove)
- Service control (start/stop container service)
- Multi-section sidebar navigation
  - Containers view with list/grid modes
  - Images management
  - Volumes management
  - Networks management
  - Statistics dashboard
  - Settings interface
- Inspector panel for detailed container information
- Auto-refresh with smart update detection
- Keyboard shortcuts for common operations
- Settings and preferences
- Support for Apple's container tool

### Technical Features
- Built with Swift and SwiftUI
- Native macOS 14.0+ support
- Dual-mode operation (menu bar + desktop)
- Efficient polling with change detection
- Thread-safe stats collection
- Flexible command parsing
- Multi-command fallback for compatibility

---

## Release Notes Format

Each release includes:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements
- **Documentation**: Documentation updates

---

[1.1.0]: https://github.com/yourusername/container-manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/yourusername/container-manager/releases/tag/v1.0.0
