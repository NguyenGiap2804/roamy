import { createHash, createHmac, randomBytes } from 'crypto';

import { AppError } from '../../utils/errors';

export type AccessTokenPayload = {
  sub: string;
  email: string;
  type: 'access';
  iat: number;
  exp: number;
};

const accessTokenTtlSeconds = 15 * 60;
const refreshTokenBytes = 48;

export function signAccessToken(input: { userId: string; email: string }) {
  const now = Math.floor(Date.now() / 1000);
  const payload: AccessTokenPayload = {
    sub: input.userId,
    email: input.email,
    type: 'access',
    iat: now,
    exp: now + accessTokenTtlSeconds,
  };

  const header = encode({ alg: 'HS256', typ: 'JWT' });
  const body = encode(payload);
  const signature = sign(`${header}.${body}`);
  return `${header}.${body}.${signature}`;
}

export function verifyAccessToken(token: string): AccessTokenPayload | null {
  const [header, body, signature] = token.split('.');
  if (!header || !body || !signature) {
    return null;
  }

  if (signature !== sign(`${header}.${body}`)) {
    return null;
  }

  try {
    const payload = JSON.parse(
      Buffer.from(body, 'base64url').toString('utf8'),
    ) as AccessTokenPayload;
    if (
      payload.type !== 'access' ||
      !payload.sub ||
      !payload.email ||
      payload.exp <= Date.now() / 1000
    ) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

export function createRefreshToken() {
  return randomBytes(refreshTokenBytes).toString('base64url');
}

export function hashSecret(value: string) {
  return createHash('sha256').update(`${authSecret()}:${value}`).digest('hex');
}

function encode(value: unknown) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function sign(value: string) {
  return createHmac('sha256', authSecret()).update(value).digest('base64url');
}

function authSecret() {
  const secret = process.env.AUTH_JWT_SECRET || process.env.ADMIN_JWT_SECRET;
  if (!secret && process.env.NODE_ENV === 'production') {
    throw new AppError(500, 'AUTH_JWT_SECRET is not configured');
  }
  return secret || 'roamy-local-user-auth-secret';
}
