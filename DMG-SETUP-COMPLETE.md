# Container Manager - DMG Packaging Setup Complete! 🎉

I've set up everything you need to package your Container Manager app as a DMG for distribution on macOS. Here's what's been created:

## 📁 New Files Created

### GitHub Actions Workflows (`.github/workflows/`)
1. **`build-dmg.yml`** - Creates unsigned DMG (good for development/testing)
2. **`build-signed-dmg.yml`** - Creates signed & notarized DMG (for public release)
3. **`build-test.yml`** - Runs tests on every push (CI)

### Scripts
4. **`scripts/create-dmg.sh`** - Local script to build DMG manually

### Build Tools
5. **`Makefile`** - Convenient commands for building and packaging

### Documentation
6. **`BUILDING.md`** - Complete documentation on building and packaging
7. **`QUICKSTART-DMG.md`** - Quick reference guide

## 🚀 Getting Started

### Option 1: Quick Local Build
```bash
# Make script executable
chmod +x scripts/create-dmg.sh

# Create DMG
./scripts/create-dmg.sh 1.0.0
```

### Option 2: Using Make (Easier)
```bash
make dmg
```

### Option 3: GitHub Actions (Automated)
```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0

# GitHub will automatically:
# - Build your app
# - Create a DMG
# - Create a GitHub Release
# - Attach the DMG to the release
```

## 📦 What Gets Created

A DMG file named `container-manager-1.0.0.dmg` that contains:
- Your Container Manager app
- A link to Applications folder for easy installation
- Professional appearance with custom window size/positioning

Users can:
1. Download the DMG
2. Open it
3. Drag the app to Applications
4. Launch from Applications folder

## 🔐 Code Signing (Optional but Recommended)

For public distribution, you should sign your app to avoid security warnings.

### Quick Setup:
1. Export your "Developer ID Application" certificate from Keychain as .p12
2. Base64 encode it: `base64 -i certificate.p12 | pbcopy`
3. Add these GitHub Secrets (in repo Settings → Secrets → Actions):
   - `MACOS_CERTIFICATE` - Paste the base64 certificate
   - `MACOS_CERTIFICATE_PWD` - Your certificate password
   - `APPLE_TEAM_ID` - Your Apple Team ID
   - `NOTARIZATION_USERNAME` - Your Apple ID email
   - `NOTARIZATION_PASSWORD` - App-specific password

4. Use the `build-signed-dmg.yml` workflow

### Why Sign?
- ✅ No "unidentified developer" warnings
- ✅ Users can double-click to open
- ✅ Professional appearance
- ✅ Better security

Without signing:
- ⚠️ Users see security warnings
- ⚠️ Must right-click → Open (extra step)
- ⚠️ Less trust from users

## 🎯 Distribution Options

### 1. GitHub Releases (Recommended)
Your DMG is automatically attached to releases when you push a version tag.

Users download from: `https://github.com/yourusername/container-manager/releases`

### 2. Direct Download
Download the DMG artifact from GitHub Actions and host it yourself.

### 3. Homebrew Cask (Advanced)
Create a formula for easy installation via Homebrew.

## 🛠️ Common Commands

```bash
# Build the app
make build

# Run tests
make test

# Create DMG
make dmg

# Install to /Applications
make install

# Clean build files
make clean

# Create a release tag
make tag

# See all commands
make help
```

## 🔄 Complete Release Workflow

Here's the full process to release a new version:

1. **Update version in Xcode**
   - Open project settings
   - Update Version and Build numbers

2. **Commit changes**
   ```bash
   git add .
   git commit -m "Bump version to 1.0.0"
   git push
   ```

3. **Create and push tag**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. **Wait for GitHub Actions**
   - Go to Actions tab
   - Watch the build complete (5-10 minutes)
   - For signed builds: +15-30 min for notarization

5. **Check the Release**
   - Go to Releases tab
   - Your new release is there with DMG attached!

6. **Announce**
   - Share the release link
   - Users can download and install

## 📊 Testing Your Workflow

Before creating a real release, test it:

1. **Test locally first**
   ```bash
   make dmg
   open container-manager-*.dmg
   ```

2. **Test GitHub Actions without release**
   - Go to Actions tab
   - Select "Build and Package DMG"
   - Click "Run workflow"
   - Download artifact to test

3. **Create a test release**
   ```bash
   git tag v0.0.1-test
   git push origin v0.0.1-test
   ```

## ⚙️ Customization

### Change DMG Appearance
Edit in `scripts/create-dmg.sh` or workflow files:
```bash
--window-size 600 400    # DMG window size
--icon-size 100          # Icon size
--window-pos 200 120     # Window position on screen
```

### Change Build Settings
Edit in workflow files:
```yaml
-configuration Release   # Debug or Release
CODE_SIGN_IDENTITY=""   # For signing
```

### Add DMG Background Image
1. Create a background image (600x400px)
2. Add to `scripts/create-dmg.sh`:
   ```bash
   --background "background.png"
   ```

## 🐛 Troubleshooting

### "Scheme not found" error
Run `xcodebuild -list` to see available schemes, update workflow files.

### DMG creation fails
The workflow has a fallback to `hdiutil`. It creates a simpler but functional DMG.

### Signing fails
Check that all secrets are set correctly. Try unsigned workflow first.

### App won't open after installing
For unsigned apps:
1. Right-click → Open (first time only)
2. Or: System Settings → Privacy & Security → Open Anyway

## 📚 Next Steps

1. ✅ **Test locally**: `make dmg`
2. ✅ **Commit the new files**: `git add . && git commit -m "Add DMG build workflows"`
3. ✅ **Push to GitHub**: `git push`
4. ✅ **Test GitHub Action**: Manually trigger workflow
5. ✅ **Create first release**: `git tag v1.0.0 && git push origin v1.0.0`
6. ✅ **(Optional) Set up signing**: Add GitHub Secrets for production releases

## 📖 Documentation

- **Quick Reference**: [QUICKSTART-DMG.md](QUICKSTART-DMG.md)
- **Full Documentation**: [BUILDING.md](BUILDING.md)
- **Make Commands**: Run `make help`

## 🎉 You're All Set!

Your Container Manager app is ready to be packaged and distributed as a professional DMG installer. Choose the workflow that fits your needs:

- **Quick testing?** Use `make dmg`
- **Automated builds?** Use GitHub Actions
- **Public release?** Set up code signing first

Questions? Check the documentation files or the comments in the workflow files.

Happy shipping! 🚀
