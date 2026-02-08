.PHONY: help build clean test dmg release release-signed dmg-signed install upload-release release-workflow check-signing notarize

# Default target
help:
	@echo "Container Manager - Build Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build            Build the app (debug)"
	@echo "  release          Build the app (release, unsigned)"
	@echo "  release-signed   Build the app (release, signed with Developer ID)"
	@echo "  test             Run tests"
	@echo "  dmg              Create DMG package (unsigned)"
	@echo "  dmg-signed       Create signed DMG package"
	@echo "  clean            Clean build artifacts"
	@echo "  install          Install to /Applications"
	@echo "  run              Build and run the app"
	@echo "  tag              Create a git tag"
	@echo "  upload-release   Upload DMG to GitHub (requires VERSION=v1.0.0)"
	@echo "  release-workflow Complete release: build + package + upload"
	@echo "  check-signing    Check code signing status of DMG"
	@echo "  notarize         Submit DMG for notarization (requires APPLE_ID and TEAM_ID)"
	@echo ""
	@echo "Environment Variables:"
	@echo "  VERSION          Version tag for release (e.g., v1.0.0)"
	@echo "  SIGNING_IDENTITY Code signing identity (default: Developer ID Application: Andrew Bold)"
	@echo "  APPLE_ID         Apple ID email for notarization"
	@echo "  TEAM_ID          Team ID for notarization (default: 6Y922224CW)"
	@echo ""

# Build in debug mode
build:
	@echo "🔨 Building Container Manager (Debug)..."
	xcodebuild build \
		-scheme container-manager \
		-configuration Debug \
		-derivedDataPath ./build

# Build in release mode (unsigned)
release:
	@echo "🔨 Building Container Manager (Release - Unsigned)..."
	xcodebuild clean build \
		-scheme container-manager \
		-configuration Release \
		-derivedDataPath ./build \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Build in release mode (signed with Developer ID)
release-signed:
	@echo "🔨 Building Container Manager (Release - Signed)..."
	@SIGNING_ID="$${SIGNING_IDENTITY:-Developer ID Application: Andrew Bold (6Y922224CW)}"; \
	echo "📝 Using signing identity: $$SIGNING_ID"; \
	xcodebuild clean build \
		-scheme container-manager \
		-configuration Release \
		-derivedDataPath ./build \
		CODE_SIGN_IDENTITY="$$SIGNING_ID" \
		CODE_SIGN_STYLE=Manual \
		DEVELOPMENT_TEAM=6Y922224CW \
		CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
		OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"
	@echo "✅ Signed build complete"

# Run tests
test:
	@echo "🧪 Running tests..."
	xcodebuild test \
		-scheme container-manager \
		-destination 'platform=macOS'

# Create DMG (unsigned)
dmg: release
	@echo "📦 Creating DMG (unsigned)..."
	@chmod +x scripts/create-dmg.sh
	@./scripts/create-dmg.sh
	@echo "🔗 Creating container-manager.dmg symlink for upload..."
	@rm -f container-manager.dmg
	@ln -s $$(ls -t container-manager-*.dmg | head -n1) container-manager.dmg
	@echo "✅ DMG ready: container-manager.dmg -> $$(readlink container-manager.dmg)"

# Create signed DMG (for distribution)
dmg-signed: release-signed
	@echo "📦 Creating signed DMG..."
	@APP_PATH=$$(find ./build -name "container-manager.app" -type d | head -n 1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ Signed app not found. Run 'make release-signed' first"; \
		exit 1; \
	fi; \
	VERSION="signed-$$(date +%Y%m%d-%H%M)"; \
	DMG_NAME="container-manager-$$VERSION.dmg"; \
	echo "📦 Packaging signed app into DMG..."; \
	rm -rf dmg_contents/; \
	mkdir -p dmg_contents/; \
	cp -R "$$APP_PATH" dmg_contents/; \
	hdiutil create -volname "Container Manager" -srcfolder dmg_contents -ov -format UDZO "$$DMG_NAME"; \
	rm -rf dmg_contents/; \
	echo "🔐 Signing DMG..."; \
	SIGNING_ID="$${SIGNING_IDENTITY:-Developer ID Application: Andrew Bold (6Y922224CW)}"; \
	codesign --sign "$$SIGNING_ID" \
		--timestamp \
		--options runtime \
		"$$DMG_NAME"; \
	echo "🔗 Creating container-manager.dmg symlink..."; \
	rm -f container-manager.dmg; \
	ln -s "$$DMG_NAME" container-manager.dmg; \
	echo "✅ Signed DMG ready: container-manager.dmg -> $$DMG_NAME"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Verify signing: make check-signing"
	@echo "  2. Notarize: make notarize APPLE_ID=your-email@example.com"
	@echo "  3. Upload: make upload-release VERSION=v1.0.0"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf build/
	rm -f *.dmg
	rm -rf dmg_contents/
	xcodebuild clean -scheme container-manager || true

# Install to Applications
install: release
	@echo "📲 Installing to /Applications..."
	@APP_PATH=$$(find ./build -name "container-manager.app" -type d | head -n 1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ App not found. Build failed?"; \
		exit 1; \
	fi; \
	if [ -d "/Applications/container-manager.app" ]; then \
		echo "⚠️  Removing existing installation..."; \
		rm -rf "/Applications/container-manager.app"; \
	fi; \
	cp -R "$$APP_PATH" /Applications/; \
	echo "✅ Installed to /Applications/container-manager.app"

# Build and run
run: build
	@echo "🚀 Launching Container Manager..."
	@APP_PATH=$$(find ./build -name "container-manager.app" -type d | head -n 1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ App not found. Build failed?"; \
		exit 1; \
	fi; \
	open "$$APP_PATH"

# Create a release tag
tag:
	@read -p "Enter version (e.g., 1.0.0): " version; \
	if [ -z "$$version" ]; then \
		echo "❌ Version required"; \
		exit 1; \
	fi; \
	echo "Creating tag v$$version..."; \
	git tag -a "v$$version" -m "Release v$$version"; \
	echo "✅ Tag created. Push with: git push origin v$$version"

# Upload release to GitHub
upload-release:
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ VERSION not set. Usage: make upload-release VERSION=v1.0.0"; \
		exit 1; \
	fi
	@if ! command -v gh &> /dev/null && ! test -x /opt/homebrew/bin/gh && ! test -x /usr/local/bin/gh; then \
		echo "❌ GitHub CLI (gh) not installed. Install with: brew install gh"; \
		exit 1; \
	fi
	@if [ ! -f "container-manager.dmg" ]; then \
		echo "❌ DMG not found. Run 'make dmg' first"; \
		exit 1; \
	fi
	@echo "📤 Uploading $(VERSION) to GitHub..."
	@GH_BIN=$$(command -v gh || echo /opt/homebrew/bin/gh || echo /usr/local/bin/gh); \
	$$GH_BIN release create $(VERSION) \
		container-manager.dmg \
		--title "Container Manager $(VERSION)" \
		--notes "Release $(VERSION)" \
		--draft
	@GH_BIN=$$(command -v gh || echo /opt/homebrew/bin/gh || echo /usr/local/bin/gh); \
	echo "✅ Release draft created at https://github.com/$$($$GH_BIN repo view --json nameWithOwner -q .nameWithOwner)/releases"
	@echo "📝 Edit the release notes and publish when ready"

# Complete release workflow: build, package, and create draft release
release-workflow:
	@read -p "Enter version (e.g., v1.0.0): " version; \
	if [ -z "$$version" ]; then \
		echo "❌ Version required"; \
		exit 1; \
	fi; \
	echo "🚀 Starting release workflow for $$version..."; \
	$(MAKE) clean; \
	$(MAKE) dmg; \
	$(MAKE) upload-release VERSION=$$version; \
	echo ""; \
	echo "✅ Release workflow complete!"; \
	echo "🔗 Go to GitHub to review and publish the draft release"

# Check code signing status
check-signing:
	@if [ ! -f "container-manager.dmg" ]; then \
		echo "❌ DMG not found. Run 'make dmg' first"; \
		exit 1; \
	fi
	@chmod +x scripts/check-signing.sh
	@./scripts/check-signing.sh container-manager.dmg

# Notarize DMG with Apple
notarize:
	@if [ -z "$(APPLE_ID)" ]; then \
		echo "❌ APPLE_ID not set. Usage: make notarize APPLE_ID=your-email@example.com"; \
		exit 1; \
	fi
	@if [ ! -f "container-manager.dmg" ]; then \
		echo "❌ DMG not found. Run 'make dmg-signed' first"; \
		exit 1; \
	fi
	@echo "🍎 Submitting DMG for notarization..."
	@echo "   This will use the notarytool keychain profile if configured"
	@echo "   Or prompt for app-specific password if not configured"
	@echo ""
	@TEAM=$${TEAM_ID:-6Y922224CW}; \
	xcrun notarytool submit container-manager.dmg \
		--apple-id "$(APPLE_ID)" \
		--team-id "$$TEAM" \
		--wait
	@echo ""
	@echo "🎫 Stapling notarization ticket to DMG..."
	@xcrun stapler staple container-manager.dmg
	@echo ""
	@echo "✅ Notarization complete!"
	@echo "   Run 'make check-signing' to verify"
