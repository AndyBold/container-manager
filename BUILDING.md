# Building and Packaging Container Manager

This document explains how to build and package Container Manager as a DMG for distribution.

## Automated Building with GitHub Actions

We have two GitHub Actions workflows available:

### 1. Basic DMG Build (Unsigned)
**File:** `.github/workflows/build-dmg.yml`

This workflow creates an unsigned DMG that can be used for development and testing. It's the simplest option and requires no setup.

**Triggers:**
- Automatically when you push a tag like `v1.0.0`
- Manually via GitHub Actions UI (workflow_dispatch)

**Usage:**
```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

The DMG will be:
- Uploaded as a GitHub Actions artifact (available for 90 days)
- Attached to a GitHub Release if triggered by a tag

### 2. Signed and Notarized DMG Build
**File:** `.github/workflows/build-signed-dmg.yml`

This workflow creates a signed and optarized DMG suitable for public distribution. Users won't see scary warnings when opening your app.

**Requirements:**
You need to set up these GitHub Secrets:

1. **MACOS_CERTIFICATE** (Required for signing)
   - Export your "Developer ID Application" certificate from Keychain
   - Right-click certificate → Export → Save as .p12
   - Base64 encode it:
     ```bash
     base64 -i certificate.p12 | pbcopy
     ```
   - Paste into GitHub Secrets

2. **MACOS_CERTIFICATE_PWD** (Required for signing)
   - The password you set when exporting the .p12 file

3. **APPLE_TEAM_ID** (Required for signing)
   - Your 10-character Apple Developer Team ID
   - Find it at https://developer.apple.com/account

4. **NOTARIZATION_USERNAME** (Optional, for notarization)
   - Your Apple ID email address

5. **NOTARIZATION_PASSWORD** (Optional, for notarization)
   - An app-specific password from https://appleid.apple.com
   - NOT your regular Apple ID password

**Setting up GitHub Secrets:**
1. Go to your repository on GitHub
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret listed above

## Manual Building

### Build from Xcode
1. Open the project in Xcode
2. Select Product → Archive
3. Click "Distribute App" → "Copy App"
4. Save the .app file

### Create DMG Manually
```bash
# Install create-dmg
brew install create-dmg

# Create DMG
create-dmg \
  --volname "Container Manager" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "container-manager.app" 175 120 \
  --app-drop-link 425 120 \
  container-manager.dmg \
  /path/to/container-manager.app
```

## Distribution Options

### Option 1: GitHub Releases (Recommended)
When you push a version tag, the workflow automatically creates a GitHub Release with the DMG attached.

Users can download it from: `https://github.com/YOUR_USERNAME/YOUR_REPO/releases`

### Option 2: Direct Download
Upload the DMG artifact from GitHub Actions to your own hosting.

### Option 3: App Store
For App Store distribution, you'll need to:
1. Configure App Store Connect
2. Use a different archive process
3. Submit through Xcode or Transporter

## Code Signing Notes

### Why Sign?
- Unsigned apps show "App from unidentified developer" warnings
- Users must right-click → Open (extra friction)
- Some security settings may block unsigned apps entirely

### Why Notarize?
- Notarization validates your app with Apple
- Reduces security warnings
- Required for macOS 10.15+ (Catalina and later)
- Shows your app is malware-free

### Without Signing (Development)
Users will need to:
1. Right-click the app
2. Select "Open"
3. Click "Open" in the security dialog
4. (macOS 13+) Go to System Settings → Privacy & Security → Allow

## Troubleshooting

### Build fails with "Scheme not found"
Your scheme name might be different. Check in Xcode or run:
```bash
xcodebuild -list
```
Update the `-scheme` parameter in the workflow.

### DMG creation fails
The workflow has a fallback to use `hdiutil` if `create-dmg` fails. The DMG will be simpler but functional.

### "No identity found" error
You haven't set up code signing secrets, or they're incorrect. Use the unsigned workflow instead.

### Notarization times out
Notarization can take 5-30 minutes. The workflow uses `--wait` which should handle this, but very large apps might exceed GitHub Actions timeout (6 hours).

## Version Numbering

We recommend semantic versioning:
- **v1.0.0** - Major release
- **v1.1.0** - New features
- **v1.1.1** - Bug fixes

Update your version in Xcode:
1. Select your project in the navigator
2. Select the target
3. General tab → Version and Build numbers
4. Commit these changes before tagging

## Testing the Workflow

Test without creating a release:
1. Go to Actions tab on GitHub
2. Select the workflow
3. Click "Run workflow"
4. Download the artifact to test

## Next Steps

1. Choose unsigned or signed workflow
2. Set up GitHub Secrets (if using signed workflow)
3. Update version in Xcode
4. Commit and push
5. Create and push a version tag
6. Wait for the workflow to complete
7. Download or share the DMG!
