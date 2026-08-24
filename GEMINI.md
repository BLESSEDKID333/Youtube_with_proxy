# Workspace Rules for YouTube-iOS6

This file outlines the constraints and settings needed to compile the iOS 6 application and deploy the proxy server configuration.

## iOS 6 Client Compilation
* **iOS SDK Location:** The host Mac has a legacy Xcode installation containing the iOS 6.1 SDK at:
  `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk`
  Always use this SDK path as `-isysroot` when compiling. Do not use the default macOS CommandLineTools SDK.
* **Architecture:** The target architecture is `armv7` (32-bit ARM).
* **Build Script:** Run `./build.sh` on the host Mac to compile, link, and sign the executable. The compiled binary will be placed in `YouTube.app/YouTube`.

## VPS Deployment & Server Details
* **VPS Setup:** Execute `VPS/setup.sh` on your Linux VPS to install Nginx proxy rules and stream extraction CGI scripts.

## Nginx & CGI Configurations
* **Nginx Cookie Domain Variable:** Use standard Nginx `$host` variable (e.g., `proxy_cookie_domain .youtube.com $host;`).
* **Python system-wide pip restrictions (PEP 668):** Download standalone `yt-dlp` binary directly:
  `curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp` and `chmod 755 /usr/local/bin/yt-dlp`.
