# Signed Release Guide

This guide covers creating properly signed and notarized releases for public distribution.

## Quick Start

### For Development/Testing (Unsigned)
```bash
make dmg
```
Creates an unsigned DMG suitable for personal use and testing.

### For Public Distribution (Signed + Notarized)
```bash
# 1. Build and sign
make dmg-signed

# 2. Verify signing
make check-signing

# 3. Submit for notarization (first time only - setup credentials)
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your-email@example.com" \
  --team-id "6Y922224CW" \
  --password "app-specific-password"

# 4. Notarize the DMG
make notarize APPLE_ID=your-email@example.com

# 5. Verify notarization
make check-signing

# 6. Upload to GitHub
make upload-release VERSION=v1.0.0
```

## Prerequisites

### Required
- ✅ Apple Developer Account ($99/year)
- ✅ Developer ID Application certificate installed
- ✅ GitHub CLI (`gh`) installed

### For Notarization
- Apple ID email
- App-specific password (generate at appleid.apple.com)
- Team ID: `6Y922224CW`

## Detailed Steps

### 1. Build and Sign

```bash
make clean
make dmg-signed
```

This will:
- Build the app with Developer ID signing
- Package it into a DMG
- Sign the DMG with Developer ID
- Apply hardened runtime flags
- Add secure timestamps

**Output:** `container-manager-signed-YYYYMMDD-HHMM.dmg`

### 2. Verify Signing

```bash
make check-signing
```

You should see:
- ✅ DMG is signed (Developer ID Application)
- ✅ App is properly signed
- ✅ Signature is valid
- ❌ App is not notarized (until step 4)

### 3. Set Up Notarization Credentials (First Time Only)

Generate an app-specific password:
1. Go to https://appleid.apple.com
2. Sign in → Security → App-Specific Passwords
3. Generate password for "notarytool"
4. Copy the password (it won't be shown again)

Store credentials in keychain:
```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your-email@example.com" \
  --team-id "6Y922224CW" \
  --password "app-specific-password"
```

### 4. Notarize

```bash
make notarize APPLE_ID=your-email@example.com
```

This will:
- Submit DMG to Apple for malware scanning
- Wait for approval (usually 1-5 minutes)
- Staple the notarization ticket to the DMG

**Note:** The first notarization may take longer (~10-15 minutes).

### 5. Verify Notarization

```bash
make check-signing
```

Now you should see:
- ✅ DMG is signed
- ✅ App is properly signed
- ✅ Signature is valid
- ✅ App is notarized

### 6. Upload to GitHub

```bash
# Create a git tag first
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Upload as draft release
make upload-release VERSION=v1.0.0
```

This creates a draft release on GitHub. You can then:
1. Edit the release notes
2. Publish the release

## Certificate Information

**Your Developer ID:**
```
Developer ID Application: Andrew Bold (6Y922224CW)
Bundle ID: andybold.container-manager
```

**Verification:**
```bash
# List all signing identities
security find-identity -v -p codesigning

# Should show:
# 1) "Apple Development: Andrew Bold (N78FK8S7QL)"
# 2) "Developer ID Application: Andrew Bold (6Y922224CW)"
```

## Troubleshooting

### Signing Fails
```bash
# Check certificate is installed
security find-identity -v -p codesigning

# Should show Developer ID Application certificate
```

### Notarization Fails
```bash
# Check submission status
xcrun notarytool history --keychain-profile "notarytool-profile"

# View specific submission
xcrun notarytool log <submission-id> --keychain-profile "notarytool-profile"
```

### DMG Not Trusted on Other Macs
- Ensure app is signed with Developer ID (not Apple Development)
- Ensure DMG is notarized and ticket is stapled
- Run `make check-signing` to verify all steps

### "Developer Cannot Be Verified" Error
- DMG needs to be notarized
- Run `make notarize APPLE_ID=your-email@example.com`
- Verify with `spctl -a -vv container-manager.app`

## Gatekeeper Behavior

### Properly Signed + Notarized
- First launch: "Open" button appears in dialog
- Users can open directly without warnings

### Signed but Not Notarized
- First launch: Gatekeeper blocks with "cannot verify developer"
- Users must: Right-click → Open → Open

### Unsigned (Development Builds)
- First launch: Gatekeeper blocks completely
- Users must: System Settings → Privacy & Security → Open Anyway

## Make Targets Reference

| Command | Description |
|---------|-------------|
| `make dmg` | Create unsigned DMG (development) |
| `make dmg-signed` | Create signed DMG (distribution) |
| `make check-signing` | Verify signing status |
| `make notarize` | Submit for notarization |
| `make upload-release` | Upload to GitHub |
| `make clean` | Clean build artifacts |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIGNING_IDENTITY` | `Developer ID Application: Andrew Bold (6Y922224CW)` | Code signing identity |
| `APPLE_ID` | (required) | Apple ID email for notarization |
| `TEAM_ID` | `6Y922224CW` | Team ID for notarization |
| `VERSION` | (required) | Version tag for release |

## Distribution Checklist

Before uploading a release:

- [ ] Clean build: `make clean`
- [ ] Create signed DMG: `make dmg-signed`
- [ ] Verify signing: `make check-signing` shows ✅
- [ ] Notarize: `make notarize APPLE_ID=your-email@example.com`
- [ ] Verify notarization: `make check-signing` shows notarized
- [ ] Test on clean Mac (no Xcode/dev tools)
- [ ] Create git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Upload release: `make upload-release VERSION=v1.0.0`
- [ ] Edit release notes on GitHub
- [ ] Publish release

## Additional Resources

- [Apple Developer Documentation - Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](docs/CODE_SIGNING_GUIDE.md) - Detailed technical reference
- [Release Process](docs/RELEASE_PROCESS.md) - Full workflow documentation

## Support

For signing and notarization issues:
- Apple Developer Forums: https://developer.apple.com/forums/
- Apple Developer Support: https://developer.apple.com/contact/

For build system issues:
- Check: `docs/CODE_SIGNING_GUIDE.md`
- Run: `make check-signing` for diagnostics
