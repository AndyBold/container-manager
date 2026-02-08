# Release Quick Start

## Create a Release in One Command

```bash
make release-workflow
```

Then enter the version (e.g., `v1.0.0`) when prompted.

That's it! 🎉

## What It Does

1. Cleans old builds
2. Builds release version
3. Creates DMG package
4. Uploads to GitHub as draft
5. Opens release page for editing

## After Running

1. Go to the GitHub URL (printed in output)
2. Edit the release notes
3. Add screenshots if you want
4. Click "Publish release"

## Other Useful Commands

```bash
make help              # See all available commands
make clean             # Clean build artifacts
make dmg               # Just build DMG (no upload)
make test              # Run tests
make install           # Install to /Applications
```

## Manual Upload (Alternative)

```bash
# Build
make clean dmg

# Upload manually at:
# https://github.com/AndyBold/container-manager/releases/new
```

---

For more details, see: `docs/RELEASE_PROCESS.md`
