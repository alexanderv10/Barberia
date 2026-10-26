import { test } from 'node:test';
import assert from 'node:assert/strict';
import { corsOrigins, jwtSecret } from '../src/common/configure-app';
import { normalizeText } from '../src/common/input';

test('rechaza secretos de ejemplo y CORS con comodines o rutas', () => {
  const oldSecret = process.env.JWT_SECRET, oldCors = process.env.CORS_ORIGINS;
  try {
    for (const secret of ['', 'short', 'replace-with-a-random-secret-of-at-least-32-characters']) {
      process.env.JWT_SECRET = secret;
      assert.throws(jwtSecret);
    }
    process.env.JWT_SECRET = 'unit-test-only-random-value-of-32-characters';
    assert.equal(jwtSecret(), process.env.JWT_SECRET);
    for (const origins of ['', '*', 'https://web.example/path', 'https://web.example/']) {
      process.env.CORS_ORIGINS = origins;
      assert.throws(corsOrigins);
    }
    process.env.CORS_ORIGINS = 'http://localhost:8080,https://web.example';
    assert.deepEqual(corsOrigins(), ['http://localhost:8080', 'https://web.example']);
  } finally {
    if (oldSecret === undefined) delete process.env.JWT_SECRET; else process.env.JWT_SECRET = oldSecret;
    if (oldCors === undefined) delete process.env.CORS_ORIGINS; else process.env.CORS_ORIGINS = oldCors;
  }
});
test('normaliza textos sin perder apóstrofes, acentos o saltos de descripción', () => {
  assert.equal(normalizeText("  Jose\u0301   O'Connor  "), "José O'Connor");
  assert.equal(normalizeText('  Primera\r\nsegunda  ', true), 'Primera\nsegunda');
  assert.equal(normalizeText(42), 42);
});
