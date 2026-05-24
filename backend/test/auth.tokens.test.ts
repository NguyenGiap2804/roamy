import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createRefreshToken,
  hashSecret,
  signAccessToken,
  verifyAccessToken,
} from '../src/modules/auth/auth.tokens';

test('access token signs and verifies user identity', () => {
  process.env.AUTH_JWT_SECRET = 'test-auth-secret';
  const token = signAccessToken({
    userId: 'user-1',
    email: 'user@example.com',
  });

  const payload = verifyAccessToken(token);

  assert.equal(payload?.sub, 'user-1');
  assert.equal(payload?.email, 'user@example.com');
  assert.equal(payload?.type, 'access');
});

test('access token verification rejects tampered tokens', () => {
  process.env.AUTH_JWT_SECRET = 'test-auth-secret';
  const token = signAccessToken({
    userId: 'user-1',
    email: 'user@example.com',
  });

  assert.equal(verifyAccessToken(`${token}x`), null);
});

test('refresh tokens are random and stored as stable hashes', () => {
  process.env.AUTH_JWT_SECRET = 'test-auth-secret';
  const first = createRefreshToken();
  const second = createRefreshToken();

  assert.notEqual(first, second);
  assert.equal(first.length > 40, true);
  assert.equal(hashSecret(first), hashSecret(first));
  assert.notEqual(hashSecret(first), first);
});
