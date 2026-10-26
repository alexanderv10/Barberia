import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('CSP bloquea scripts inline/eval y solo permite el decodificador QR versionado', async () => {
  const headers = JSON.parse(await readFile(new URL('./security-headers.json', import.meta.url), 'utf8'));
  const csp = headers['Content-Security-Policy'];
  const scriptSrc = csp.split(';').map(d => d.trim()).find(d => d.startsWith('script-src '));
  assert(scriptSrc.includes("'self'"));
  assert(scriptSrc.includes("'wasm-unsafe-eval'"));
  assert(!scriptSrc.includes("'unsafe-inline'"));
  assert(!scriptSrc.includes("'unsafe-eval'"));
  assert(!scriptSrc.includes('*'));
  assert(scriptSrc.includes('https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.3/dist/iife/reader/index.js'));
  assert(csp.includes("object-src 'none'"));
  assert(csp.includes("frame-ancestors 'none'"));
  assert.equal(headers['Permissions-Policy'], 'camera=(self), microphone=(), geolocation=()');
  const nginx = await readFile(new URL('./nginx-local.conf', import.meta.url), 'utf8');
  for (const [name, value] of Object.entries(headers)) assert(nginx.includes(`add_header ${name} "${value}" always;`));
});
