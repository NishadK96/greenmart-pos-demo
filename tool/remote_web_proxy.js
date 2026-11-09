// Local development only: serve the built Flutter app and the remote ERP API
// under one localhost origin, so browser cookie authentication works.
const http = require('http');
const https = require('https');

const host = '127.0.0.1';
const port = Number(process.env.EAZY_POS_PROXY_PORT || 5082);
const appPort = Number(process.env.EAZY_POS_APP_PORT || 8080);
const erpHost = 'eazyerp.co';
const erpCookieNames = new Set([
  'connector_device_id',
  'connector_device_secret',
  'XSRF-TOKEN',
  'eazyerp_session',
]);

function erpCookies(cookieHeader) {
  return (cookieHeader || '')
    .split(';')
    .map((cookie) => cookie.trim())
    .filter((cookie) => erpCookieNames.has(cookie.split('=', 1)[0]))
    .join('; ');
}

http.createServer({maxHeaderSize: 128 * 1024}, (request, response) => {
  const remote = ['/connector/', '/uploads/', '/storage/'].some((prefix) =>
    request.url.startsWith(prefix),
  );
  const headers = {...request.headers};
  // Localhost cookies are shared across ports. Other local app cookies can
  // exceed the Flutter dev server's header limit and do not belong upstream.
  delete headers.cookie;
  if (remote) {
    const cookie = erpCookies(request.headers.cookie);
    if (cookie) headers.cookie = cookie;
  }
  const upstream = (remote ? https : http).request({
    hostname: remote ? erpHost : host,
    port: remote ? 443 : appPort,
    method: request.method,
    path: request.url,
    headers: {
      ...headers,
      host: remote ? erpHost : `${host}:${appPort}`,
    },
  }, (upstreamResponse) => {
    process.stdout.write(
      `${request.method} ${request.url} -> ${upstreamResponse.statusCode ?? 502}\n`,
    );
    response.writeHead(upstreamResponse.statusCode ?? 502, upstreamResponse.headers);
    upstreamResponse.pipe(response);
  });
  upstream.on('error', () => {
    response.writeHead(502, {'content-type': 'text/plain; charset=utf-8'});
    response.end('Local ERP proxy could not reach its upstream.');
  });
  request.pipe(upstream);
}).listen(port, host, () => {
  process.stdout.write(`Eazy POS local run: http://${host}:${port}\n`);
});
