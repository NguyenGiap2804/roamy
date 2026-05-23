import { createHmac, timingSafeEqual } from 'crypto';
import { Request, Response, NextFunction } from 'express';

import { AppError } from '../../utils/errors';

type AdminTokenPayload = {
  sub: 'roamy-admin';
  email: string;
  iat: number;
  exp: number;
};

const tokenTtlSeconds = 60 * 60 * 12;

export function authenticateAdmin(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  const header = req.get('authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7).trim() : '';

  if (!token || !verifyAdminToken(token)) {
    return next(new AppError(401, 'Admin authentication required'));
  }

  return next();
}

export function loginAdmin(email: string, password: string) {
  const configuredEmail = adminEmail();
  const configuredPassword = process.env.ADMIN_PASSWORD;

  if (!configuredPassword && process.env.NODE_ENV === 'production') {
    throw new AppError(500, 'Admin credentials are not configured');
  }

  const validEmail = email.trim().toLowerCase() === configuredEmail.toLowerCase();
  const validPassword = password === (configuredPassword ?? 'admin123');

  if (!validEmail || !validPassword) {
    throw new AppError(401, 'Invalid admin credentials');
  }

  return {
    token: signAdminToken(configuredEmail),
    admin: {
      email: configuredEmail,
      name: 'Roamy Admin',
    },
  };
}

function signAdminToken(email: string) {
  const now = Math.floor(Date.now() / 1000);
  const payload: AdminTokenPayload = {
    sub: 'roamy-admin',
    email,
    iat: now,
    exp: now + tokenTtlSeconds,
  };

  const header = encode({ alg: 'HS256', typ: 'JWT' });
  const body = encode(payload);
  const signature = sign(`${header}.${body}`);
  return `${header}.${body}.${signature}`;
}

function verifyAdminToken(token: string) {
  const [header, body, signature] = token.split('.');
  if (!header || !body || !signature) {
    return false;
  }

  if (!safeEqual(signature, sign(`${header}.${body}`))) {
    return false;
  }

  try {
    const payload = JSON.parse(
      Buffer.from(body, 'base64url').toString('utf8'),
    ) as AdminTokenPayload;
    return payload.sub === 'roamy-admin' && payload.exp > Date.now() / 1000;
  } catch {
    return false;
  }
}

function encode(value: unknown) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function sign(value: string) {
  return createHmac('sha256', adminJwtSecret()).update(value).digest('base64url');
}

function safeEqual(first: string, second: string) {
  const firstBuffer = Buffer.from(first);
  const secondBuffer = Buffer.from(second);
  return (
    firstBuffer.length === secondBuffer.length &&
    timingSafeEqual(firstBuffer, secondBuffer)
  );
}

function adminEmail() {
  return process.env.ADMIN_EMAIL || 'admin@roamy.local';
}

function adminJwtSecret() {
  const secret = process.env.ADMIN_JWT_SECRET;
  if (!secret && process.env.NODE_ENV === 'production') {
    throw new AppError(500, 'ADMIN_JWT_SECRET is not configured');
  }
  return secret || 'roamy-local-admin-secret';
}
