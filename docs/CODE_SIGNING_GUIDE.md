# Code Signing Verification Guide

This guide explains how to verify code signing on your DMG and app bundles.

## Current Status

**Default builds are UNSIGNED (adhoc signing only).**

This is intentional and works fine for:
- Development and testing
- Personal use
- Distribution to trusted users who can right-click → Open

For wider distribution, you'll want proper code signing and notarization.

## Quick Verification Commands

### Check DMG Signature
```bash
codesign -dvv container-manager.dmg
```

**Unsigned DMG output:**
```
container-manager.dmg: code object is not signed at all
```

**Signed DMG output:**
```
Executable=container-manager.dmg
Identifier=com.yourcompany.container-manager-dmg
Format=disk image
CodeDirectory v=20400 size=...
Signature size=...
Authority=Developer ID Application: Your Name (TEAMID)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
Timestamp=Feb 8, 2026 at 5:00:00 PM
Info.plist=not bound
TeamIdentifier=YOURTEAMID
Sealed Resources=none
Internal requirements count=1 size=...
```

### Check App Bundle Signature
```bash
# Mount the DMG first
hdiutil attach container-manager.dmg -readonly -mountpoint /tmp/check

# Check the app
codesign -dvvv /Volumes/*/container-manager.app

# Unmount
hdiutil detach /tmp/check
```

**Adhoc (unsigned) output:**
```
Signature=adhoc
TeamIdentifier=not set
```

**Properly signed output:**
```
Signature size=...
Authority=Developer ID Application: Your Name (TEAMID)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
TeamIdentifier=YOURTEAMID
```

### Verify Signature (Deep Check)
```bash
codesign --verify --deep --strict --verbose=2 /path/to/container-manager.app
```

**Success (valid signature):**
```
/path/to/container-manager.app: valid on disk
/path/to/container-manager.app: satisfies its Designated Requirement
```

**Failure:**
```
/path/to/container-manager.app: code object is not signed at all
# or
/path/to/container-manager.app: invalid signature (code or signature have been modified)
```

### Check Notarization Status
```bash
spctl -a -vv /path/to/container-manager.app
```

**Notarized:**
```
/path/to/container-manager.app: accepted
source=Notarized Developer ID
origin=Developer ID Application: Your Name (TEAMID)
```

**Not notarized:**
```
/path/to/container-manager.app: rejected
source=no usable signature
```

## Understanding Signing States

### 1. Adhoc Signed (Current Default)
- **What**: App is "self-signed" by the linker during build
- **Security**: Basic integrity checking only
- **Distribution**: Works for development, personal use
- **Gatekeeper**: Will show warning on first launch
- **Override**: Users can right-click → Open to bypass

### 2. Developer ID Signed
- **What**: Signed with Apple Developer certificate
- **Security**: Verified by Apple's identity system
- **Distribution**: Can distribute outside App Store
- **Gatekeeper**: Will verify signature but may warn if not notarized
- **Requires**: Apple Developer account ($99/year)

### 3. Developer ID Signed + Notarized
- **What**: Signed AND scanned by Apple for malware
- **Security**: Highest level for non-App Store apps
- **Distribution**: Professional distribution
- **Gatekeeper**: No warnings, launches immediately
- **Requires**: Developer ID + notarization workflow

### 4. App Store Signed
- **What**: Signed for App Store distribution
- **Security**: Sandboxed and reviewed by Apple
- **Distribution**: Only through Mac App Store
- **Gatekeeper**: No warnings
- **Requires**: App Store entitlements, review process

## How to Sign Your Builds

### Prerequisites
1. Apple Developer account ($99/year)
2. Developer ID Application certificate
3. Developer ID Installer certificate (for DMGs)

### Install Certificate
1. Log in to https://developer.apple.com
2. Go to Certificates, Identifiers & Profiles
3. Create "Developer ID Application" certificate
4. Download and install in Keychain Access

### Find Your Signing Identity
```bash
security find-identity -v -p codesigning
```

Output shows available identities:
```
1) ABC123DEF456... "Developer ID Application: Your Name (TEAMID)"
2) XYZ789GHI012... "Apple Development: your.email@example.com (TEAMID)"
```

Use the "Developer ID Application" identity for distribution.

### Sign the App
```bash
# Set your identity
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Build with signing
make dmg SIGNING_IDENTITY="$SIGNING_IDENTITY"
```

Or manually:
```bash
# Build unsigned first
make release

# Find the app
APP_PATH=$(find ./build -name "container-manager.app" -type d | head -n 1)

# Sign it
codesign --force --deep --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --timestamp \
  "$APP_PATH"

# Verify
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
```

### Sign the DMG
```bash
# After creating DMG
codesign --force --sign "$SIGNING_IDENTITY" \
  --timestamp \
  container-manager.dmg

# Verify
codesign -dvv container-manager.dmg
```

## Notarization

After signing, submit for notarization:

### 1. Create App-Specific Password
1. Go to https://appleid.apple.com
2. Sign in
3. Security → App-Specific Passwords
4. Generate new password for "notarytool"

### 2. Submit for Notarization
```bash
xcrun notarytool submit container-manager.dmg \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait
```

### 3. Staple Ticket
```bash
# Staple to DMG
xcrun stapler staple container-manager.dmg

# Verify stapling
xcrun stapler validate container-manager.dmg
```

## Distribution Checklist

### For Development/Testing (Current)
- [x] Build with `make dmg`
- [x] Verify app launches
- [x] Test core functionality
- [ ] No signing needed

### For Trusted Users
- [x] Build with `make dmg`
- [ ] Sign app with Developer ID
- [ ] Create DMG
- [ ] Sign DMG
- [ ] Distribute with instructions to right-click → Open on first launch

### For Public Distribution
- [x] Build with `make dmg`
- [ ] Sign app with Developer ID
- [ ] Enable hardened runtime
- [ ] Create DMG
- [ ] Sign DMG
- [ ] Notarize with Apple
- [ ] Staple notarization ticket
- [ ] Verify with spctl
- [ ] Upload to GitHub Releases

## Troubleshooting

### "Developer cannot be verified"
**Cause**: App is not signed or not notarized
**Solution**: User right-clicks app → Open (one time)
**Better solution**: Sign and notarize your app

### "Code signature is invalid"
**Cause**: App was modified after signing
**Solution**: Clean build and re-sign

### "Notarization failed"
**Cause**: App doesn't meet notarization requirements
**Solution**: Check notarization log:
```bash
xcrun notarytool log <submission-id> \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

### "timestamp authority not found"
**Cause**: No internet during signing
**Solution**: Ensure internet connection and retry

## Current Build Status

Your current builds are:
- ✅ **Adhoc signed** (linker-signed during build)
- ❌ Not Developer ID signed
- ❌ Not notarized
- ⚠️ Will show Gatekeeper warning on first launch

This is fine for:
- Development
- Testing
- Personal use
- Distribution to technical users

For wider distribution, follow the signing and notarization steps above.

## References

- [Apple Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [codesign man page](x-man-page://codesign)
- [spctl man page](x-man-page://spctl)

---

**Last Updated**: 2026-02-08
