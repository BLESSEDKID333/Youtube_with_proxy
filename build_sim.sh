#!/bin/sh
set -e

SDK=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator6.1.sdk
CLANG=/Library/Developer/CommandLineTools/usr/bin/clang
SRC=YouTube
ARCH=i386
MIN_VER=6.0
OPT="-Os"

FRAMEWORKS="-framework UIKit -framework Foundation -framework CoreGraphics \
            -framework CFNetwork -framework Security \
            -framework SystemConfiguration -framework MediaPlayer \
            -framework MessageUI -framework AudioToolbox \
            -framework CoreAudio -framework AVFoundation \
            -lz -lsqlite3 -lxml2"

INCLUDES="-I$SRC -I$SRC/Controllers -I$SRC/Networking -I$SRC/Model -I$SRC/Views \
          -I$SDK/usr/include/libxml2"

CFLAGS="-arch $ARCH -isysroot $SDK -mios-simulator-version-min=$MIN_VER $OPT $INCLUDES -fobjc-arc"

SOURCES="
$SRC/main.m
$SRC/AppDelegate.m
$SRC/DebugLog.m
$SRC/AuthManager.m
$SRC/Model/YTVideo.m
$SRC/Networking/YouTubeAPIManager.m
$SRC/Networking/ImageCacheManager.m
$SRC/Networking/YouTubeProxyURLProtocol.m
$SRC/Controllers/MainTabBarController.m
$SRC/Controllers/TrendingViewController.m
$SRC/Controllers/CategoriesViewController.m
$SRC/Controllers/CategoryVideosViewController.m
$SRC/Controllers/SearchViewController.m
$SRC/Controllers/VideoPlayerViewController.m
$SRC/Controllers/SubscriptionsViewController.m
$SRC/Controllers/SettingsViewController.m
$SRC/Controllers/BypassSettingsViewController.m
$SRC/Controllers/ChannelViewController.m
$SRC/Controllers/LoginViewController.m
$SRC/Controllers/WebLoginViewController.m
$SRC/Views/VideoCell.m
$SRC/VideoURLCache.m
"

rm -rf obj_sim
mkdir -p obj_sim

echo "=== Compiling for iOS 6.1 Simulator (i386) ==="
for src in $SOURCES; do
    objfile="obj_sim/$(basename $src .m).o"
    echo "  $src -> $objfile"
    $CLANG $CFLAGS -c "$src" -o "$objfile"
done

mkdir -p YouTube_Sim.app
echo "=== Linking ==="
$CLANG -arch $ARCH -isysroot $SDK obj_sim/*.o \
    $FRAMEWORKS \
    -o YouTube_Sim.app/YouTube

cp YouTube/Info.plist YouTube_Sim.app/Info.plist

# Launch images — Default-568h@2x.png unlocks full iPhone 5 (568pt) screen on iOS 6
for img in Default.png Default@2x.png Default-568h@2x.png; do
    [ -f "YouTube/$img" ] && cp "YouTube/$img" "YouTube_Sim.app/$img"
done

# Target Simulator Applications directory
SIM_DIR="$HOME/Library/Application Support/iPhone Simulator/6.1/Applications/YouTubeAppGUID"
mkdir -p "$SIM_DIR"
cp -r YouTube_Sim.app "$SIM_DIR/"

echo "=== Launching iOS 6 Simulator ==="
open "/Applications/Xcode.app/Contents/Applications/iPhone Simulator.app"
echo "=== Done! Application installed into iOS 6 Simulator ==="
