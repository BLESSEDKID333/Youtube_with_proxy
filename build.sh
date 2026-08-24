#!/bin/sh
set -e

SDK=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk
CLANG=/Library/Developer/CommandLineTools/usr/bin/clang
SRC=YouTube
ARCH=armv7
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

CFLAGS="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_VER $OPT $INCLUDES -fobjc-arc"

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

rm -rf obj
mkdir -p obj

echo "=== Compiling ==="
for src in $SOURCES; do
    objfile="obj/$(basename $src .m).o"
    echo "  $src -> $objfile"
    $CLANG $CFLAGS -c "$src" -o "$objfile"
done

echo "=== Linking ==="
$CLANG -arch $ARCH -isysroot $SDK obj/*.o \
    $FRAMEWORKS \
    -o YouTube.app/YouTube

cp YouTube/Info.plist YouTube.app/Info.plist

echo "=== Signing ==="
ldid -S YouTube.app/YouTube

echo "=== Done ==="
