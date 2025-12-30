.PHONY: help build clean test dmg release install

# Default target
help:
	@echo "Container Manager - Build Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build       Build the app (debug)"
	@echo "  release     Build the app (release)"
	@echo "  test        Run tests"
	@echo "  dmg         Create DMG package"
	@echo "  clean       Clean build artifacts"
	@echo "  install     Install to /Applications"
	@echo "  run         Build and run the app"
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
