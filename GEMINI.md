# Workspace Rules for YouTube-iOS6

This file outlines the constraints, credentials, and settings needed to compile the iOS 6 application and deploy the proxy server configuration.

## iOS 6 Client Compilation
* **iOS SDK Location:** The host Mac has a legacy Xcode 4.6.3 installation containing the iOS 6.1 SDK at:
  `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk`
  Always use this SDK path as `-isysroot` when compiling. Do not use the default macOS CommandLineTools SDK.
* **Architecture:** The target architecture is `armv7` (32-bit ARM). Host compilers may warn about this target, but compilation is supported using the iOS 6.1 SDK.
* **Build Script:** Run `./build.sh` on the host Mac to compile, link, and sign the executable. The compiled binary will be placed in `YouTube.app/YouTube`.

## VPS Deployment & Server Details
* **VPS IP Address:** `192.144.13.102`
* **SSH/Sudo Credentials:**
  - Username: `user1`
  - Password: `Chiter228&`
* **Sudo execution:** Run commands via SSH using `sudo -S` and feed the password `Chiter228&` to standard input when executing `setup.sh` or modifying system files.
* **Working Directory:** Spawning remote commands via SSH (e.g. `paramiko`) creates a fresh shell. Ensure you change directory to `/tmp` before running the setup script (i.e. `sudo -S bash -c "cd /tmp && ./setup.sh"`).

## Nginx & CGI Configurations
* **Nginx Cookie Domain Variable:** Do not use custom shell variables like `$VPS_IP` inside Nginx configuration files, as Nginx will throw an `unknown variable` error. Instead, use the standard Nginx `$host` variable (e.g., `proxy_cookie_domain .youtube.com $host;`).
* **Python system-wide pip restrictions (PEP 668):** When setting up `yt-dlp` on the VPS, avoid running `pip3 install` system-wide. Instead, download the standalone binary directly:
  `curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp` and `chmod 755 /usr/local/bin/yt-dlp`.
