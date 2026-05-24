import assert from 'node:assert/strict';
import test from 'node:test';
import type { NextFunction, Request, Response } from 'express';

import { authenticateAdmin, loginAdmin } from '../src/modules/admin/admin.auth';
import { resetAdminLoginRateLimitForTests } from '../src/modules/admin/admin.rate-limit';
import { AppError } from '../src/utils/errors';

test('admin login returns a signed token for valid credentials', () => {
  resetAdminLoginRateLimitForTests();
  const restoreEnv = withAdminEnv();

  try {
    const result = loginAdmin('admin@example.com', 'secret-password', {
      ipAddress: '127.0.0.1',
    });

    assert.equal(result.admin.email, 'admin@example.com');
    assert.equal(typeof result.token, 'string');
    assert.equal(result.token.split('.').length, 3);
  } finally {
    restoreEnv();
  }
});

test('admin login rejects invalid credentials', () => {
  resetAdminLoginRateLimitForTests();
  const restoreEnv = withAdminEnv();

  try {
    assert.throws(
      () =>
        loginAdmin('admin@example.com', 'wrong-password', {
          ipAddress: '127.0.0.1',
        }),
      (error: unknown) => {
        assert(error instanceof AppError);
        assert.equal(error.statusCode, 401);
        return true;
      },
    );
  } finally {
    restoreEnv();
  }
});

test('admin login rate limits repeated invalid credentials', () => {
  resetAdminLoginRateLimitForTests();
  const restoreEnv = withAdminEnv();

  try {
    for (let index = 0; index < 5; index += 1) {
      assert.throws(() =>
        loginAdmin('admin@example.com', 'wrong-password', {
          ipAddress: '10.0.0.8',
        }),
      );
    }

    assert.throws(
      () =>
        loginAdmin('admin@example.com', 'wrong-password', {
          ipAddress: '10.0.0.8',
        }),
      (error: unknown) => {
        assert(error instanceof AppError);
        assert.equal(error.statusCode, 429);
        return true;
      },
    );
  } finally {
    restoreEnv();
    resetAdminLoginRateLimitForTests();
  }
});

test('admin login success clears previous failed attempts', () => {
  resetAdminLoginRateLimitForTests();
  const restoreEnv = withAdminEnv();

  try {
    assert.throws(() =>
      loginAdmin('admin@example.com', 'wrong-password', {
        ipAddress: '10.0.0.9',
      }),
    );

    const result = loginAdmin('admin@example.com', 'secret-password', {
      ipAddress: '10.0.0.9',
    });
    assert.equal(result.admin.email, 'admin@example.com');
  } finally {
    restoreEnv();
    resetAdminLoginRateLimitForTests();
  }
});

test('admin middleware rejects requests without bearer token', () => {
  const nextError = invokeAdminMiddleware({
    get: () => undefined,
  } as unknown as Request);

  assert(nextError instanceof AppError);
  assert.equal(nextError.statusCode, 401);
});

test('admin middleware accepts a valid bearer token', () => {
  resetAdminLoginRateLimitForTests();
  const restoreEnv = withAdminEnv();

  try {
    const result = loginAdmin('admin@example.com', 'secret-password');
    const nextError = invokeAdminMiddleware({
      get: (header: string) =>
        header.toLowerCase() === 'authorization'
          ? `Bearer ${result.token}`
          : undefined,
    } as unknown as Request);

    assert.equal(nextError, undefined);
  } finally {
    restoreEnv();
  }
});

function invokeAdminMiddleware(req: Request) {
  let capturedError: unknown;
  const next: NextFunction = (error?: unknown) => {
    capturedError = error;
  };

  authenticateAdmin(req, {} as Response, next);
  return capturedError;
}

function withAdminEnv() {
  const previous = {
    ADMIN_EMAIL: process.env.ADMIN_EMAIL,
    ADMIN_PASSWORD: process.env.ADMIN_PASSWORD,
    ADMIN_JWT_SECRET: process.env.ADMIN_JWT_SECRET,
    NODE_ENV: process.env.NODE_ENV,
  };

  process.env.ADMIN_EMAIL = 'admin@example.com';
  process.env.ADMIN_PASSWORD = 'secret-password';
  process.env.ADMIN_JWT_SECRET = 'test-admin-secret';
  process.env.NODE_ENV = 'test';

  return () => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  };
}
