# Quick Start: Creating a DMG

## Fastest Method (Local Build)

```bash
# Make script executable (first time only)
chmod +x scripts/create-dmg.sh

# Create DMG
./scripts/create-dmg.sh 1.0.0
```

Your DMG will be created in the current directory: `container-manager-1.0.0.dmg`

## Using GitHub Actions (Recommended)

### For Development/Testing (Unsigned)

1. Push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. Go to your repo's Actions tab
3. Wait for the build to complete
4. Download the DMG artifact

### For Production (Signed & Notarized)

1. **One-time setup:** Add these GitHub Secrets:
   - `MACOS_CERTIFICATE` - Your Developer ID certificate (base64 encoded .p12)
   - `MACOS_CERTIFICATE_PWD` - Certificate password
   - `APPLE_TEAM_ID` - Your Apple Team ID
   - `NOTARIZATION_USERNAME` - Your Apple ID
   - `NOTARIZATION_PASSWORD` - App-specific password

2. Enable the signed workflow:
   ```bash
   # Use build-signed-dmg.yml instead of build-dmg.yml
   # (Both are already in your repo)
   ```

3. Push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. GitHub will automatically:
   - Build your app
   - Sign it
   - Notarize it with Apple
   - Create a DMG
   - Create a GitHub Release
   - Attach the DMG to the release

## Which Method Should I Use?

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **Local Script** | Quick testing | Fast, simple | Manual, no signing |
| **GitHub Actions (Unsigned)** | Beta testing | Automated, consistent | Shows security warnings |
| **GitHub Actions (Signed)** | Public release | No warnings, professional | Requires Apple Developer account |

## Distributing Your App

Once you have a DMG:

### Option 1: GitHub Releases (Easiest)
Your DMG is automatically attached to releases when using GitHub Actions with tags.

Users download from: `https://github.com/yourusername/container-manager/releases`

### Option 2: Manual Upload
Download the DMG artifact and upload to your own website/server.

### Option 3: Homebrew Cask
Create a Homebrew formula for easy installation:
```bash
brew install --cask container-manager
```
(Requires creating a Homebrew tap)

## Testing Your DMG

```bash
# Open the DMG
open container-manager-1.0.0.dmg

# Drag the app to Applications
# Launch from Applications folder
```

**Note:** Unsigned apps require right-click → Open on first launch.

## Need Help?

See [BUILDING.md](BUILDING.md) for detailed documentation.
