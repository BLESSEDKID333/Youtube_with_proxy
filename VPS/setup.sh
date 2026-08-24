#!/bin/bash
# VPS setup for YouTube-iOS6 — nginx + fcgiwrap
# Run on a Debian/Ubuntu VPS (tested on Ubuntu 24.04)

set -e

export DEBIAN_FRONTEND=noninteractive

echo "[*] Updating packages..."
apt-get update -y

echo "[*] Installing nginx, fcgiwrap, python3, pip, ffmpeg, nodejs..."
apt-get install -y nginx fcgiwrap python3 python3-pip ffmpeg curl nodejs

echo "[*] Installing yt-dlp..."
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
chmod 755 /usr/local/bin/yt-dlp

# Detect VPS IP
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_VPS_IP")

echo "[*] Setting up CGI directory..."
mkdir -p /var/www/cgi-bin
chmod 755 /var/www/cgi-bin

mkdir -p /var/www/html
chmod 755 /var/www/html

# Copy CGI scripts (rename extract to .py for fcgiwrap)
cp usr/lib/cgi-bin/ytlogin /var/www/cgi-bin/ytlogin
chmod 755 /var/www/cgi-bin/ytlogin

cp usr/lib/cgi-bin/extract /var/www/cgi-bin/extract.py
chmod 755 /var/www/cgi-bin/extract.py

echo "[*] Checking yt-dlp location..."
YTDLP_PATH=$(which yt-dlp 2>/dev/null || echo "/usr/local/bin/yt-dlp")
if [ -L "$YTDLP_PATH" ]; then
    REAL_YTDLP=$(readlink -f "$YTDLP_PATH")
    if echo "$REAL_YTDLP" | grep -q "^/home/"; then
        echo "[!] yt-dlp is a symlink into user home — www-data can't access it."
        echo "[*] Copying to /usr/local/bin/yt-dlp..."
        cp "$REAL_YTDLP" /usr/local/bin/yt-dlp
        chmod 755 /usr/local/bin/yt-dlp
    fi
fi

echo "[*] Setting up SNI Forwarder service..."
cp sni_forwarder.py /usr/local/bin/sni_forwarder.py
chmod 755 /usr/local/bin/sni_forwarder.py

cat > /etc/systemd/system/sni-forwarder.service << 'SYSTEMDEOF'
[Unit]
Description=SNI SOCKS5 Forwarder for Nginx YouTube Proxy
After=network.target warp-svc.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/sni_forwarder.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SYSTEMDEOF

systemctl daemon-reload
systemctl enable sni-forwarder
systemctl restart sni-forwarder

systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true

echo "[*] Configuring nginx..."

# ==================== Port 80 — Main proxy ====================
cat > /etc/nginx/sites-available/ytproxy << 'NGINXEOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    client_max_body_size 10m;

    resolver 8.8.8.8 1.1.1.1 valid=300s ipv6=off;
    proxy_ssl_server_name on;
    proxy_ssl_protocols TLSv1.2 TLSv1.3;

    proxy_buffer_size 64k;
    proxy_buffers 8 64k;
    proxy_busy_buffers_size 128k;

    # CORS
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-YouTube-Client-Name, X-YouTube-Client-Version, User-Agent, Origin, Referer" always;

    if ($request_method = OPTIONS) {
        return 204;
    }

    # YouTube InnerTube API
    location /youtubei/ {
        proxy_pass https://127.0.0.1:8443/youtubei/;
        proxy_set_header Host www.youtube.com;
        proxy_ssl_name www.youtube.com;
        proxy_ssl_server_name on;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 30s;
    }

    # YouTube web proxy (watch pages, etc.)
    location /youtube/ {
        proxy_pass https://127.0.0.1:8443/;
        proxy_set_header Host www.youtube.com;
        proxy_ssl_name www.youtube.com;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
        proxy_set_header Accept-Language en-US;
        proxy_set_header Accept-Encoding "";
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 60s;

        proxy_cookie_domain .youtube.com $host;
        proxy_cookie_domain youtube.com $host;
        proxy_cookie_flags ~ nosecure;

        proxy_redirect https://accounts.google.com/ /google-accounts/;
        proxy_redirect https://www.youtube.com/ /youtube/;
        proxy_redirect https://youtube.com/ /youtube/;
        proxy_redirect https://google.com/ /google-accounts/;
        proxy_redirect https://www.google.com/ /google-accounts/;
        proxy_redirect https://ssl.gstatic.com/ /gstatic/ssl.gstatic.com/;
    }

    # Google Accounts (OAuth login flow)
    location /google-accounts/ {
        proxy_pass https://127.0.0.1:8443/;
        proxy_set_header Host accounts.google.com;
        proxy_ssl_name accounts.google.com;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent $http_user_agent;
        proxy_set_header Accept-Language en-US;
        proxy_set_header Accept-Encoding "";
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 60s;

        proxy_cookie_domain .google.com $host;
        proxy_cookie_domain .accounts.google.com $host;
        proxy_cookie_flags ~ nosecure;

        proxy_redirect https://accounts.google.com/ /google-accounts/;
        proxy_redirect https://www.youtube.com/ /youtube/;
        proxy_redirect https://youtube.com/ /youtube/;
        proxy_redirect https://google.com/ /google-accounts/;
        proxy_redirect https://www.google.com/ /google-accounts/;
        proxy_redirect https://ssl.gstatic.com/ /gstatic/ssl.gstatic.com/;
    }

    # Video proxy: /ytproxy/<host>/<path> -> https://<host>/<path>
    location /ytproxy/ {
        rewrite ^/ytproxy/(.+?)(/.*)$ /$2 break;
        proxy_pass https://127.0.0.1:8443;
        proxy_set_header Host $1;
        proxy_ssl_name $1;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 30s;
    }

    # googlevideo.com direct proxy
    location /googlevideo/ {
        rewrite ^/googlevideo/(.+?)(/.*)$ /$2 break;
        proxy_pass https://127.0.0.1:8443;
        proxy_set_header Host $1;
        proxy_ssl_name $1;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 60s;
        proxy_buffering off;
    }

    # Thumbnails
    location /vi/ {
        proxy_pass https://127.0.0.1:8443/vi/;
        proxy_set_header Host i.ytimg.com;
        proxy_ssl_name i.ytimg.com;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0";
        proxy_cache_valid 200 1d;
        proxy_read_timeout 10s;
    }

    # Google static assets (SSL gstatic)
    location /gstatic/ {
        rewrite ^/gstatic/(.+?)(/.*)$ /$2 break;
        proxy_pass https://127.0.0.1:8443;
        proxy_set_header Host $1;
        proxy_ssl_name $1;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0";
        proxy_read_timeout 10s;
    }

    # ==================== CGI via fcgiwrap ====================
    location /api/extract {
        gzip off;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME /var/www/cgi-bin/extract.py;
        fastcgi_param QUERY_STRING $query_string;
        fastcgi_param REQUEST_METHOD $request_method;
        fastcgi_param CONTENT_TYPE $content_type;
        fastcgi_param CONTENT_LENGTH $content_length;
        fastcgi_param SERVER_PROTOCOL $server_protocol;
        fastcgi_param REMOTE_ADDR $remote_addr;
        include fastcgi_params;
        fastcgi_read_timeout 60s;
    }

    location ~ ^/cgi-bin/(.*)$ {
        gzip off;
        include fastcgi_params;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME /var/www/cgi-bin/$1;
        fastcgi_read_timeout 120s;
    }
}
NGINXEOF

# ==================== Port 9090 — Lightweight YouTube proxy (iOS 6 webview) ====================
cat > /etc/nginx/sites-available/ytproxy-mobile << 'MOBILEEOF'
server {
    listen 9090;
    server_name _;

    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-YouTube-Client-Name, X-YouTube-Client-Version, User-Agent, Origin, Referer" always;

    if ($request_method = OPTIONS) {
        return 204;
    }

    # InnerTube API
    location /youtubei/ {
        proxy_pass https://127.0.0.1:8443/youtubei/;
        proxy_set_header Host www.youtube.com;
        proxy_ssl_name www.youtube.com;
        proxy_ssl_server_name on;
        proxy_set_header Accept "";
        proxy_set_header Accept-Encoding "";
        proxy_set_header Connection "";
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_read_timeout 30s;
        proxy_connect_timeout 10s;
    }

    # Thumbnails
    location /vi/ {
        proxy_pass https://127.0.0.1:8443/vi/;
        proxy_set_header Host i.ytimg.com;
        proxy_ssl_name i.ytimg.com;
        proxy_ssl_server_name on;
        proxy_http_version 1.1;
    }

    location /img/ {
        proxy_pass https://127.0.0.1:8443/img/;
        proxy_set_header Host img.youtube.com;
        proxy_ssl_name img.youtube.com;
        proxy_ssl_server_name on;
        proxy_http_version 1.1;
    }

    # YouTube embed player
    location /embed/ {
        proxy_pass https://127.0.0.1:8443/embed/;
        proxy_set_header Host www.youtube.com;
        proxy_ssl_name www.youtube.com;
        proxy_ssl_server_name on;
        proxy_set_header Accept "";
        proxy_set_header Accept-Encoding "";
        proxy_set_header Connection "";
        proxy_http_version 1.1;
        proxy_buffering off;
    }

    # YouTube mobile watch page
    location /m.youtube.com/ {
        proxy_pass https://127.0.0.1:8443/;
        proxy_set_header Host m.youtube.com;
        proxy_ssl_name m.youtube.com;
        proxy_ssl_server_name on;
        proxy_set_header Accept "";
        proxy_set_header Accept-Encoding "";
        proxy_set_header Connection "";
        proxy_http_version 1.1;
        proxy_buffering off;
    }

    # YouTube generic assets (CSS, JS, images)
    location /s/ {
        proxy_pass https://127.0.0.1:8443/s/;
        proxy_set_header Host www.youtube.com;
        proxy_ssl_name www.youtube.com;
        proxy_ssl_server_name on;
        proxy_http_version 1.1;
    }

    location / {
        return 404 '{"error":"not found"}';
        add_header Content-Type application/json always;
    }
}
MOBILEEOF

# Enable sites
ln -sf /etc/nginx/sites-available/ytproxy /etc/nginx/sites-enabled/ytproxy
ln -sf /etc/nginx/sites-available/ytproxy-mobile /etc/nginx/sites-enabled/ytproxy-mobile
rm -f /etc/nginx/sites-enabled/default

echo "[*] Testing nginx config..."
nginx -t

echo "[*] Restarting nginx, fcgiwrap, and sni-forwarder..."
systemctl restart sni-forwarder
systemctl restart nginx || service nginx restart
systemctl restart fcgiwrap || service fcgiwrap restart

echo ""
echo "[==============================================]"
echo "[*] Setup complete!"
echo "[*] VPS IP: $VPS_IP"
echo "[*] Login form: http://$VPS_IP/cgi-bin/ytlogin"
echo "[*] Extract API: http://$VPS_IP/api/extract?videoId=VIDEO_ID"
echo "[*] Web proxy: http://$VPS_IP/youtube/"
echo "[*] Mobile proxy: http://$VPS_IP:9090/"
echo "[*] Update VPSProxyBase() in Constants.h to: http://$VPS_IP"
echo "[==============================================]"
echo ""
echo "[!] IMPORTANT: Make sure to update VPS_BASE in Constants.h"
echo "    or set the VPS_BASE environment variable on the server."
echo ""
echo "[!] Test the setup:"
echo "    curl -s 'http://$VPS_IP/api/extract?videoId=dQw4w9WgXcQ' | python3 -m json.tool"
