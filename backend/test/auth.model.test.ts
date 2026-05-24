import assert from 'node:assert/strict';
import test from 'node:test';

import {
  loginSchema,
  registerSchema,
  resetPasswordSchema,
  verifyEmailSchema,
} from '../src/modules/auth/auth.model';

test('register validates password policy and normalizes email', () => {
  const result = registerSchema.safeParse({
    body: {
      name: 'Nguyen Giap',
      email: '  GIAP@example.COM ',
      password: 'abc12345',
    },
  });

  assert.equal(result.success, true);
  if (result.success) {
    assert.equal(result.data.body.email, 'giap@example.com');
  }

  const weak = registerSchema.safeParse({
    body: {
      name: 'Nguyen Giap',
      email: 'giap@example.com',
      password: 'abcdefgh',
    },
  });
  assert.equal(weak.success, false);
});

test('auth schemas require email and six digit verification codes', () => {
  assert.equal(
    loginSchema.safeParse({
      body: { email: 'user@example.com', password: 'secret' },
    }).success,
    true,
  );
  assert.equal(
    verifyEmailSchema.safeParse({
      body: { email: 'user@example.com', code: '123456' },
    }).success,
    true,
  );
  assert.equal(
    verifyEmailSchema.safeParse({
      body: { email: 'user@example.com', code: 'abc456' },
    }).success,
    false,
  );
  assert.equal(
    resetPasswordSchema.safeParse({
      body: { email: 'user@example.com', code: '123456', password: 'new12345' },
    }).success,
    true,
  );
});
