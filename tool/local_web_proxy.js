const http = require('http');

const listenHost = '127.0.0.1';
const listenPort = Number(process.env.EAZY_POS_PROXY_PORT || 5082);
const flutterPort = Number(process.env.EAZY_POS_APP_PORT || 5083);
const backendPort = Number(process.env.EAZY_POS_BACKEND_PORT || 8080);
const webAuthCookies = new Map();

function captureWebAuthCookies(setCookieHeaders = []) {
  for (const header of setCookieHeaders) {
    const pair = header.split(';', 1)[0];
    const separator = pair.indexOf('=');
    if (separator <= 0) continue;
    webAuthCookies.set(pair.slice(0, separator), pair.slice(separator + 1));
  }
}

function webAuthCookieHeader() {
  return [...webAuthCookies.entries()]
    .map(([name, value]) => `${name}=${value}`)
    .join('; ');
}

const server = http.createServer({maxHeaderSize: 64 * 1024}, (request, response) => {
  const isBackendRequest =
    request.url.startsWith('/connector/') ||
    request.url.startsWith('/uploads/') ||
    request.url.startsWith('/storage/');
  const isWebAuthBootstrap =
    request.method === 'GET' &&
    request.url.startsWith('/connector/web-auth/bootstrap');
  const upstreamHeaders = {
    ...request.headers,
    host: isBackendRequest
      ? `localhost:${backendPort}`
      : `${listenHost}:${flutterPort}`,
  };

  // A local backend restart can invalidate Laravel-encrypted device cookies.
  // Bootstrap without stale cookies so the backend can issue a fresh device
  // identity; the browser keeps the replacement Set-Cookie headers normally.
  if (isWebAuthBootstrap) {
    delete upstreamHeaders.cookie;
  } else if (
    request.url.startsWith('/connector/web-auth/') &&
    webAuthCookies.size > 0
  ) {
    upstreamHeaders.cookie = webAuthCookieHeader();
  } else if (request.url.startsWith('/connector/api/')) {
    // Connector API calls authenticate with their Bearer token. Forwarding
    // unrelated stale Laravel cookies can make middleware reject the request
    // before token authentication is evaluated.
    delete upstreamHeaders.cookie;
  }
  const upstream = http.request(
    {
      hostname: '127.0.0.1',
      port: isBackendRequest ? backendPort : flutterPort,
      method: request.method,
      path: request.url,
      headers: upstreamHeaders,
    },
    (upstreamResponse) => {
      if (request.url.startsWith('/connector/web-auth/')) {
        captureWebAuthCookies(upstreamResponse.headers['set-cookie']);
      }
      response.writeHead(upstreamResponse.statusCode ?? 502, upstreamResponse.headers);
      upstreamResponse.pipe(response);
    },
  );

  upstream.on('error', (error) => {
    response.writeHead(502, {'content-type': 'text/plain; charset=utf-8'});
    response.end(`Local upstream unavailable: ${error.message}`);
  });
  request.pipe(upstream);
});

server.listen(listenPort, listenHost, () => {
  process.stdout.write(
    `Eazy POS local proxy: http://${listenHost}:${listenPort} ` +
      `(Flutter :${flutterPort}, ERP :${backendPort})\n`,
  );
});
