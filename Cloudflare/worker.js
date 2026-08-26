/**
 * Cloudflare Worker Reverse Proxy for YouTube iOS 6 Client
 * 
 * Instructions:
 * 1. Log in to your Cloudflare Dashboard -> Workers & Pages -> Create Worker.
 * 2. Paste this entire worker.js code into the Cloudflare Worker code editor.
 * 3. Click "Save and Deploy".
 * 4. Use your worker URL (e.g. https://yt-proxy.subdomain.workers.dev) as the Proxy Host in the iOS 6 YouTube app!
 */

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  const url = new URL(request.url);

  // Handle CORS Preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-YouTube-Client-Name, X-YouTube-Client-Version, User-Agent, Origin, Referer',
      }
    });
  }

  // 1. YouTube InnerTube API Proxy
  if (url.pathname.startsWith('/youtubei/')) {
    const targetUrl = 'https://www.youtube.com' + url.pathname + url.search;
    return proxyRequest(request, targetUrl, 'www.youtube.com');
  }

  // 2. Thumbnails Proxy (/vi/*)
  if (url.pathname.startsWith('/vi/')) {
    const targetUrl = 'https://i.ytimg.com' + url.pathname + url.search;
    return proxyRequest(request, targetUrl, 'i.ytimg.com');
  }

  // 3. Google Accounts OAuth Login Proxy (/google-accounts/*)
  if (url.pathname.startsWith('/google-accounts/')) {
    const subPath = url.pathname.replace('/google-accounts/', '/');
    const targetUrl = 'https://accounts.google.com' + subPath + url.search;
    return proxyRequest(request, targetUrl, 'accounts.google.com');
  }

  // 4. Video Proxy (/ytproxy/<host>/<path>)
  if (url.pathname.startsWith('/ytproxy/')) {
    const parts = url.pathname.split('/');
    if (parts.length >= 3) {
      const targetHost = parts[2];
      const targetPath = '/' + parts.slice(3).join('/');
      const targetUrl = 'https://' + targetHost + targetPath + url.search;
      return proxyRequest(request, targetUrl, targetHost);
    }
  }

  // Default Status / Health Check Page
  return new Response(JSON.stringify({
    status: "ok",
    service: "YouTube iOS 6 Cloudflare Worker Proxy",
    version: "1.0.0"
  }), {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

async function proxyRequest(request, targetUrl, hostHeader) {
  const newHeaders = new Headers(request.headers);
  newHeaders.set('Host', hostHeader);
  newHeaders.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36');
  newHeaders.delete('cf-connecting-ip');
  newHeaders.delete('cf-worker');
  newHeaders.delete('cf-ray');

  const modifiedRequest = new Request(targetUrl, {
    method: request.method,
    headers: newHeaders,
    body: request.method !== 'GET' && request.method !== 'HEAD' ? await request.arrayBuffer() : null,
    redirect: 'follow'
  });

  try {
    const response = await fetch(modifiedRequest);
    const responseHeaders = new Headers(response.headers);
    responseHeaders.set('Access-Control-Allow-Origin', '*');
    responseHeaders.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    responseHeaders.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-YouTube-Client-Name, X-YouTube-Client-Version, User-Agent, Origin, Referer');

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: responseHeaders
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
}
