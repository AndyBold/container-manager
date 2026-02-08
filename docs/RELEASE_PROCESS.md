# Release Process

This document describes how to build and release Container Manager.

## Prerequisites

1. **GitHub CLI** - Install if you don't have it:
   ```bash
   brew install gh
   gh auth login
   ```

2. **Xcode Command Line Tools** - Should already be installed
   ```bash
   xcode-select --install
   ```

3. **(Optional) Code Signing** - Apple Developer account with signing certificate
   - Not required for unsigned builds
   - Required for distribution outside development

## Quick Release Workflow

The easiest way to create a release:

```bash
make release-workflow
# Enter version when prompted (e.g., v1.0.0)
```

This will:
1. Clean previous builds
2. Build the release version
3. Create a DMG package
4. Upload as a draft release to GitHub
5. Open the GitHub releases page for you to edit notes and publish

## Step-by-Step Manual Process

If you prefer to do it step-by-step:

### 1. Build the Release

```bash
make clean
make dmg
```

This creates `container-manager.dmg` in the project root.

### 2. Test the DMG

```bash
open container-manager.dmg
# Drag app to /Applications and test it
```

### 3. Upload to GitHub

```bash
make upload-release VERSION=v1.0.0
```

This creates a **draft release** on GitHub. The release won't be public until you publish it.

### 4. Edit Release Notes

1. Go to GitHub releases page (printed in terminal output)
2. Edit the release notes with details about changes
3. Add screenshots or other assets if desired
4. Click "Publish release" when ready

## Code Signing (Optional)

If you have an Apple Developer account and want to sign the app:

```bash
# Set your signing identity
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Build will automatically sign if identity is set
make dmg
```

To find your signing identities:
```bash
security find-identity -v -p codesigning
```

## Notarization (Optional)

For distribution outside the Mac App Store, you should notarize:

```bash
# After building the DMG
xcrun notarytool submit container-manager.dmg \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple the notarization ticket
xcrun stapler staple container-manager.dmg
```

**Note**: App-specific passwords can be created at [appleid.apple.com](https://appleid.apple.com).

## Version Numbering

We use semantic versioning: `vMAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes

Examples:
- `v1.0.0` - First major release
- `v1.1.0` - Added new feature
- `v1.1.1` - Bug fix

## Git Tagging

Create a git tag for the release:

```bash
make tag
# Enter version when prompted (e.g., 1.0.0)

# Push the tag
git push origin v1.0.0
```

## Release Checklist

Before releasing:

- [ ] All tests pass: `make test`
- [ ] Version number updated in relevant files
- [ ] CHANGELOG.md updated with changes
- [ ] README.md updated if needed
- [ ] Build and test the DMG locally
- [ ] Review release notes
- [ ] Git tag created and pushed
- [ ] GitHub release published

## Troubleshooting

### "gh: command not found"

Install GitHub CLI:
```bash
brew install gh
gh auth login
```

### "xcrun: error: unable to find utility"

Install Xcode Command Line Tools:
```bash
xcode-select --install
```

### Build fails with code signing errors

Either:
1. Provide valid signing identity: `export SIGNING_IDENTITY="..."`
2. Use unsigned build (default) - disable Gatekeeper on target machines

### DMG not created

Check that the build succeeded:
```bash
ls -la ./build/Build/Products/Release/
```

The app should be at `./build/Build/Products/Release/container-manager.app`

## Examples

### Create unsigned release v1.0.0
```bash
make release-workflow
# Enter: v1.0.0
```

### Create signed release v1.0.0
```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name"
make release-workflow
# Enter: v1.0.0
```

### Upload existing DMG
```bash
make upload-release VERSION=v1.0.0
```

## CI/CD (Future)

For now, we're using local builds. In the future, we can set up GitHub Actions to:
- Build on every tag push
- Run tests
- Create releases automatically
- Notarize the app

---

Last Updated: 2026-02-08
