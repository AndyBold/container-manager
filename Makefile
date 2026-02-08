.PHONY: help build clean test dmg release install upload-release release-workflow

# Default target
help:
	@echo "Container Manager - Build Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build            Build the app (debug)"
	@echo "  release          Build the app (release)"
	@echo "  test             Run tests"
	@echo "  dmg              Create DMG package"
	@echo "  clean            Clean build artifacts"
	@echo "  install          Install to /Applications"
	@echo "  run              Build and run the app"
	@echo "  tag              Create a git tag"
	@echo "  upload-release   Upload DMG to GitHub (requires VERSION=v1.0.0)"
	@echo "  release-workflow Complete release: build + package + upload"
	@echo ""
	@echo "Environment Variables:"
	@echo "  VERSION          Version tag for release (e.g., v1.0.0)"
	@echo "  SIGNING_IDENTITY Code signing identity (optional)"
	@echo ""

# Build in debug mode
build:
	@echo "🔨 Building Container Manager (Debug)..."
	xcodebuild build \
		-scheme container-manager \
		-configuration Debug \
		-derivedDataPath ./build

# Build in release mode
release:
	@echo "🔨 Building Container Manager (Release)..."
	xcodebuild clean build \
		-scheme container-manager \
		-configuration Release \
		-derivedDataPath ./build \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Run tests
test:
	@echo "🧪 Running tests..."
	xcodebuild test \
		-scheme container-manager \
		-destination 'platform=macOS'

# Create DMG
dmg: release
	@echo "📦 Creating DMG..."
	@chmod +x scripts/create-dmg.sh
	@./scripts/create-dmg.sh
	@echo "🔗 Creating container-manager.dmg symlink for upload..."
	@rm -f container-manager.dmg
	@ln -s $$(ls -t container-manager-*.dmg | head -n1) container-manager.dmg
	@echo "✅ DMG ready: container-manager.dmg -> $$(readlink container-manager.dmg)"

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
