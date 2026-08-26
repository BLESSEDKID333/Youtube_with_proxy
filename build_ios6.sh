#!/bin/bash
# Build script for YouTube iOS 6 Client
# Requires: Xcode with iOS 6.1 SDK installed
# Usage: ./build_ios6.sh

set -e

PROJECT="YouTube"
SDK_VERSION="6.1"
DEPLOYMENT_TARGET="6.0"
ARCH="armv7"

# Paths
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SRC_DIR/build"
APP_DIR="$BUILD_DIR/$PROJECT.app"

SDK="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${SDK_VERSION}.sdk"
CLANG="xcrun -sdk iphoneos clang"
# If xcrun doesn't work, use directly:
# CLANG="clang -isysroot $SDK"

# List ALL source files (both in pbxproj and additional files found on disk)
SOURCES=(
    "$SRC_DIR/YouTube/main.m"
    "$SRC_DIR/YouTube/AppDelegate.m"
    "$SRC_DIR/YouTube/DebugLog.m"
    "$SRC_DIR/YouTube/AuthManager.m"
    "$SRC_DIR/YouTube/Model/YTVideo.m"
    "$SRC_DIR/YouTube/Networking/YouTubeAPIManager.m"
    "$SRC_DIR/YouTube/Networking/YouTubeProxyURLProtocol.m"
    "$SRC_DIR/YouTube/Networking/ImageCacheManager.m"
    "$SRC_DIR/YouTube/Controllers/MainTabBarController.m"
    "$SRC_DIR/YouTube/Controllers/TrendingViewController.m"
    "$SRC_DIR/YouTube/Controllers/CategoriesViewController.m"
    "$SRC_DIR/YouTube/Controllers/CategoryVideosViewController.m"
    "$SRC_DIR/YouTube/Controllers/SearchViewController.m"
    "$SRC_DIR/YouTube/Controllers/VideoPlayerViewController.m"
    "$SRC_DIR/YouTube/Controllers/SubscriptionsViewController.m"
    "$SRC_DIR/YouTube/Controllers/SettingsViewController.m"
    "$SRC_DIR/YouTube/Controllers/LoginViewController.m"
    "$SRC_DIR/YouTube/Controllers/WebLoginViewController.m"
    "$SRC_DIR/YouTube/Controllers/ChannelViewController.m"
    "$SRC_DIR/YouTube/Controllers/BypassSettingsViewController.m"
    "$SRC_DIR/YouTube/Views/VideoCell.m"
)

# Frameworks to link
FRAMEWORKS=(
    "-framework" "UIKit"
    "-framework" "Foundation"
    "-framework" "CoreGraphics"
    "-framework" "Security"
    "-framework" "CFNetwork"
    "-framework" "SystemConfiguration"
    "-framework" "MediaPlayer"
    "-framework" "MessageUI"
    "-lz"
    "-lsqlite3.0"
)

COMMON_FLAGS=(
    -arch "$ARCH"
    -isysroot "$SDK"
    -miphoneos-version-min="$DEPLOYMENT_TARGET"
    -fobjc-arc
    -std=gnu99
    -I"$SRC_DIR/YouTube"
    -I"$SRC_DIR/YouTube/Model"
    -I"$SRC_DIR/YouTube/Networking"
    -I"$SRC_DIR/YouTube/Controllers"
    -I"$SRC_DIR/YouTube/Views"
    -include "$SRC_DIR/YouTube/YouTube-Prefix.pch"
    -DDEBUG=1
)

echo "=== Building YouTube iOS 6 Client ==="
echo "SDK: $SDK"
echo "Arch: $ARCH"
echo "Deployment: $DEPLOYMENT_TARGET"
echo "Sources: ${#SOURCES[@]} files"
echo ""

# Check SDK exists
if [ ! -d "$SDK" ]; then
    echo "ERROR: iOS $SDK_VERSION SDK not found at:"
    echo "  $SDK"
    echo "Make sure Xcode with iOS $SDK_VERSION SDK is installed."
    echo "SDKs available at:"
    ls /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/
    exit 1
fi

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/obj"
mkdir -p "$APP_DIR"

# Step 1: Compile each source file
echo "=== Compiling sources ==="
OBJ_FILES=()
for src in "${SOURCES[@]}"; do
    basename_src=$(basename "$src" .m)
    obj="$BUILD_DIR/obj/${basename_src}.o"
    OBJ_FILES+=("$obj")
    echo "  Compiling: $(basename "$src")"
    $CLANG -c "${COMMON_FLAGS[@]}" "$src" -o "$obj"
done
echo "  Done: ${#SOURCES[@]} files compiled"
echo ""

# Step 2: Link all object files into executable
echo "=== Linking ==="
$CLANG -arch "$ARCH" -isysroot "$SDK" -miphoneos-version-min="$DEPLOYMENT_TARGET" \
    "${OBJ_FILES[@]}" \
    "${FRAMEWORKS[@]}" \
    -o "$APP_DIR/$PROJECT"
echo "  Linked: $APP_DIR/$PROJECT"
file "$APP_DIR/$PROJECT"
echo ""

# Step 3: Copy Info.plist and resources
echo "=== Creating app bundle ==="
cp "$SRC_DIR/YouTube/Info.plist" "$APP_DIR/"
echo "  Copied: Info.plist"

# Launch images — Default-568h@2x.png unlocks full iPhone 5 (568pt) screen on iOS 6
for img in Default.png Default@2x.png Default-568h@2x.png; do
    if [ -f "$SRC_DIR/YouTube/$img" ]; then
        cp "$SRC_DIR/YouTube/$img" "$APP_DIR/"
        echo "  Copied: $img"
    fi
done

# Generate PkgInfo (required for iOS apps)
echo -n "APPL????" > "$APP_DIR/PkgInfo"

# Code sign (required for device, use ldid if available)
if command -v ldid &>/dev/null; then
    echo "=== Code signing with ldid ==="
    ldid -S "$APP_DIR/$PROJECT"
elif command -v codesign &>/dev/null; then
    echo "=== Code signing with codesign ==="
    codesign -f -s "iPhone Developer" "$APP_DIR/$PROJECT" 2>/dev/null || \
    echo "  WARNING: No valid code signing identity found. App may not run on device."
else
    echo "  WARNING: No code signing tool found. App may not run on device."
fi

echo ""
echo "=== Build complete ==="
echo "App bundle: $APP_DIR"
echo ""
echo "To install on device:"
echo "  1. Open Xcode Organizer"
echo "  2. Drag $APP_DIR to the Devices window"
echo ""
echo "To install via ideviceinstaller:"
echo "  cd $BUILD_DIR && zip -r YouTube.ipa Payload/"
echo "  ideviceinstaller -i YouTube.ipa"
