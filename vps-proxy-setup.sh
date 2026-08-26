#!/bin/sh
# VPS Proxy Setup for YouTube-iOS6
# Run this on a fresh Debian/Ubuntu VPS as root.
# Usage: ssh root@YOUR_VPS_IP "$(cat vps-proxy-setup.sh)"

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Must be run as root"
    exit 1
fi

apt-get update -y
apt-get install -y nginx fcgiwrap python3

# Install yt-dlp
wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
chmod 755 /usr/local/bin/yt-dlp

# Create extraction CGI script
mkdir -p /var/www/cgi-bin
cat > /var/www/cgi-bin/extract.py << 'PYEOF'
#!/usr/bin/env python3
import json, os, sys, subprocess, urllib.parse

def respond(data, code=200):
    sys.stdout.write(f"Status: {code}\r\nContent-Type: application/json\r\n\r\n{json.dumps(data)}\n")
    sys.exit(0)

qs = os.environ.get("QUERY_STRING", "")
params = dict(urllib.parse.parse_qsl(qs))
video_id = params.get("videoId", "")
if not video_id:
    respond({"error": "Missing videoId"}, 400)

fmt = params.get("fmt", "best")
try:
    r = subprocess.run(
        ["/usr/local/bin/yt-dlp", f"-f{fmt}", "--get-url", "--no-warnings",
         "--no-check-certificate", video_id],
        capture_output=True, text=True, timeout=45)
except subprocess.TimeoutExpired:
    respond({"error": "yt-dlp timed out"}, 504)

if r.returncode != 0 or not r.stdout.strip():
    err = (r.stderr or "").strip() or "No URL found"
    respond({"error": err}, 404)

url = r.stdout.strip().split("\n")[0]
respond({"url": url, "source": "yt-dlp"})
PYEOF

chmod 755 /var/www/cgi-bin/extract.py

# Create nginx config for YouTube proxy
cat > /etc/nginx/sites-available/ytproxy << 'NGINX'
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

    # InnerTube API proxy (must NOT have trailing slash!)
    location /youtubei/ {
        proxy_pass https://www.youtube.com;
        proxy_set_header Host www.youtube.com;
        proxy_ssl_name www.youtube.com;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
        proxy_set_header Accept-Language en-US;
        proxy_set_header Accept-Encoding "";
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 30s;
    }

    # Generic host proxy
    location /ytproxy/ {
        rewrite ^/ytproxy/(.+?)(/.*)$ /$2 break;
        proxy_pass https://$1;
        proxy_set_header Host $1;
        proxy_ssl_name $1;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
        proxy_set_header Accept-Language en-US;
        proxy_set_header Accept-Encoding "";
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 30s;
    }

    # googlevideo.com proxy (for video streaming)
    location /googlevideo/ {
        rewrite ^/googlevideo/(.+?)(/.*)$ /$2 break;
        proxy_pass https://$1;
        proxy_set_header Host $1;
        proxy_ssl_name $1;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 60s;
        proxy_buffering off;
    }

    # YouTube thumbnail proxy
    location /vi/ {
        proxy_pass https://i.ytimg.com/vi/;
        proxy_set_header Host i.ytimg.com;
        proxy_ssl_name i.ytimg.com;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0";
        proxy_cache_valid 200 1d;
        proxy_read_timeout 10s;
    }

    # gstatic.com proxy
    location /gstatic/ {
        rewrite ^/gstatic/(.+?)(/.*)$ /$2 break;
        proxy_pass https://$1;
        proxy_set_header Host $1;
        proxy_ssl_name $1;
        proxy_ssl_server_name on;
        proxy_set_header User-Agent "Mozilla/5.0";
        proxy_read_timeout 10s;
    }

    # Video info extraction CGI (via yt-dlp)
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
}
NGINX

ln -sf /etc/nginx/sites-available/ytproxy /etc/nginx/sites-enabled/ytproxy
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx
systemctl enable fcgiwrap
systemctl start fcgiwrap

echo ""
echo "=============================================="
echo "VPS Proxy is running on $(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
echo ""
echo "Update VPS_PROXY_DEFAULT in Constants.h to:"
echo "   http://$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
echo ""
echo "Then rebuild and enable 'обход РКН' in app Settings."
echo "=============================================="
