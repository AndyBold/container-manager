#!/bin/bash

# Script to check code signing status of DMG and app bundle
# Usage: ./scripts/check-signing.sh [path-to-dmg]

# Don't exit on error - we want to check everything
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Find DMG
if [ -n "$1" ]; then
    DMG_PATH="$1"
else
    # Find most recent DMG
    DMG_PATH=$(ls -t container-manager*.dmg 2>/dev/null | head -n1)
fi

if [ -z "$DMG_PATH" ]; then
    echo -e "${RED}❌ No DMG found${NC}"
    echo "Usage: $0 [path-to-dmg]"
    exit 1
fi

echo -e "${BLUE}🔍 Checking code signing status${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check DMG signature
echo -e "${YELLOW}📦 DMG Signature:${NC}"
echo "File: $DMG_PATH"
echo ""

DMG_SIGNED=false
if codesign -dvv "$DMG_PATH" 2>&1 | grep -q "Authority="; then
    DMG_SIGNED=true
    echo -e "${GREEN}✅ DMG is signed${NC}"
    codesign -dvv "$DMG_PATH" 2>&1 | grep -E "(Authority|TeamIdentifier|Timestamp)"
else
    echo -e "${RED}❌ DMG is not signed${NC}"
    codesign -dvv "$DMG_PATH" 2>&1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Mount DMG
echo -e "${YELLOW}📱 Mounting DMG...${NC}"
MOUNT_POINT="/tmp/signing-check-$$"
hdiutil attach "$DMG_PATH" -readonly -mountpoint "$MOUNT_POINT" -nobrowse > /dev/null 2>&1

# Find app in DMG
APP_PATH=$(find "$MOUNT_POINT" -name "*.app" -maxdepth 1 | head -n1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ No app found in DMG${NC}"
    hdiutil detach "$MOUNT_POINT" > /dev/null 2>&1
    exit 1
fi

echo "App: $(basename "$APP_PATH")"
echo ""

# Check app signature
echo -e "${YELLOW}🔐 App Bundle Signature:${NC}"
echo ""

APP_SIGNED=false
APP_ADHOC=false

if codesign -dvv "$APP_PATH" 2>&1 | grep -q "Authority="; then
    APP_SIGNED=true
    echo -e "${GREEN}✅ App is properly signed${NC}"
    codesign -dvvv "$APP_PATH" 2>&1 | grep -E "(Authority|TeamIdentifier|Timestamp|Identifier)" | head -10
elif codesign -dvv "$APP_PATH" 2>&1 | grep -q "Signature=adhoc"; then
    APP_ADHOC=true
    echo -e "${YELLOW}⚠️  App is adhoc signed (development only)${NC}"
    codesign -dvv "$APP_PATH" 2>&1 | grep -E "(Signature|TeamIdentifier|Identifier)"
else
    echo -e "${RED}❌ App is not signed${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify signature
echo -e "${YELLOW}✓  Verification:${NC}"
echo ""

if codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | grep -q "valid on disk"; then
    echo -e "${GREEN}✅ Signature is valid${NC}"
else
    echo -e "${RED}❌ Signature verification failed${NC}"
    codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check notarization
echo -e "${YELLOW}🍎 Notarization Status:${NC}"
echo ""

if spctl -a -vv "$APP_PATH" 2>&1 | grep -q "accepted"; then
    echo -e "${GREEN}✅ App is notarized${NC}"
    spctl -a -vv "$APP_PATH" 2>&1
else
    echo -e "${RED}❌ App is not notarized${NC}"
    spctl -a -vv "$APP_PATH" 2>&1 || true
fi

# Unmount
hdiutil detach "$MOUNT_POINT" > /dev/null 2>&1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Summary
echo -e "${BLUE}📊 Summary:${NC}"
echo ""

if [ "$DMG_SIGNED" = true ] && [ "$APP_SIGNED" = true ]; then
    echo -e "${GREEN}✅ Fully signed - ready for distribution${NC}"
    echo "   Both DMG and app are properly signed"
elif [ "$APP_ADHOC" = true ]; then
    echo -e "${YELLOW}⚠️  Development build - adhoc signed${NC}"
    echo "   Good for: Development, testing, personal use"
    echo "   Not suitable for: Public distribution"
    echo ""
    echo "   Users will see Gatekeeper warning on first launch"
    echo "   They can bypass with: Right-click → Open"
    echo ""
    echo "   To sign for distribution:"
    echo "   1. Get Apple Developer account"
    echo "   2. Create Developer ID certificate"
    echo "   3. See: docs/CODE_SIGNING_GUIDE.md"
else
    echo -e "${RED}❌ Not signed${NC}"
    echo "   This build is not properly signed"
    echo "   See: docs/CODE_SIGNING_GUIDE.md"
fi

echo ""
