import assert from 'node:assert/strict';
import { AddressInfo } from 'node:net';
import test from 'node:test';

import { app } from '../src/app';

test('content security policy allows HTTPS images for admin previews', async () => {
  const server = app.listen(0);
  await new Promise<void>((resolve) => {
    server.once('listening', () => resolve());
  });

  try {
    const address = server.address() as AddressInfo;
    const response = await fetch(`http://127.0.0.1:${address.port}/health`);
    const csp = response.headers.get('content-security-policy') ?? '';

    assert.match(csp, /img-src[^;]*'self'/);
    assert.match(csp, /img-src[^;]*data:/);
    assert.match(csp, /img-src[^;]*blob:/);
    assert.match(csp, /img-src[^;]*https:/);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }
});
