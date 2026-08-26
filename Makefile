export THEOS = $(HOME)/theos

ARCHS = armv7
TARGET = iphone:clang:16.5:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YouTube
YouTube_INFO_PLIST = YouTube/Info.plist

# All Objective-C sources (mirrors build.sh SOURCES, discovered via wildcard)
YouTube_FILES = $(wildcard YouTube/*.m) \
                $(wildcard YouTube/Model/*.m) \
                $(wildcard YouTube/Networking/*.m) \
                $(wildcard YouTube/Controllers/*.m) \
                $(wildcard YouTube/Views/*.m)

YouTube_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore \
                     CFNetwork Security SystemConfiguration \
                     MediaPlayer MessageUI AudioToolbox CoreAudio AVFoundation

YouTube_CFLAGS = -fobjc-arc -Os \
                 -IYouTube -IYouTube/Model -IYouTube/Networking \
                 -IYouTube/Controllers -IYouTube/Views \
                 -include YouTube/YouTube-Prefix.pch \
                 -Wno-deprecated-declarations -Wno-implicit-enum-enum-cast

# Ship the existing Info.plist + iPhone 5 launch images straight from YouTube/
# (single source of truth — no duplicate copies to keep in sync)
YouTube_RESOURCE_FILES = YouTube/Info.plist \
                         YouTube/Default.png \
                         YouTube/Default@2x.png \
                         YouTube/Default-568h@2x.png \
                         YouTube/Certs

# Ad-hoc sign so it runs on a jailbroken iOS 6 device
YouTube_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS)/makefiles/application.mk
