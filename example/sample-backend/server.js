'use strict';

/**
 * Minimal sample backend used as the "provider under test" for Microcks
 * contract testing. Implements the Sample Orders API contract from
 * examples/openapi-valid.yaml:
 *
 *   GET /orders/{orderId}
 *     200 application/json        -> { orderId: string, isPaid: boolean }
 *     400 application/problem+json -> { type, title, detail }
 *
 * Two modes, selected by the DRIFT environment variable:
 *   DRIFT unset / "false" -> conformant responses (contract test PASS)
 *   DRIFT = "true"        -> intentionally drifted responses (contract test FAIL)
 *
 * Pure Node.js, no dependencies, so the container image stays tiny and the
 * build needs no npm install.
 */

const http = require('http');

const PORT = Number(process.env.PORT) || 8081;
const DRIFT = String(process.env.DRIFT).toLowerCase() === 'true';

function sendJson(res, status, contentType, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': contentType,
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function handleGetOrder(res, orderId) {
  if (!orderId) {
    return sendJson(res, 400, 'application/problem+json', {
      type: 'https://errors.example.com/bad-request',
      title: 'Bad Request',
      detail: 'orderId path parameter is required.',
    });
  }

  if (DRIFT) {
    // Contract drift: isPaid is a string instead of boolean and a field is
    // renamed. A schema-based contract test must reject this.
    return sendJson(res, 200, 'application/json', {
      order_id: orderId,
      isPaid: 'yes',
    });
  }

  // Conformant response.
  return sendJson(res, 200, 'application/json', {
    orderId,
    isPaid: true,
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const match = url.pathname.match(/^\/orders\/([^/]+)$/);

  if (req.method === 'GET' && match) {
    return handleGetOrder(res, decodeURIComponent(match[1]));
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    return sendJson(res, 200, 'application/json', { status: 'ok' });
  }

  return sendJson(res, 404, 'application/problem+json', {
    type: 'https://errors.example.com/not-found',
    title: 'Not Found',
    detail: `No route for ${req.method} ${url.pathname}.`,
  });
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(
    `sample-backend listening on :${PORT} (DRIFT=${DRIFT ? 'true' : 'false'})`
  );
});
