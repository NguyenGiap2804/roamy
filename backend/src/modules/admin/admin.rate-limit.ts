import { AppError } from '../../utils/errors';

type AttemptRecord = {
  failedAttempts: number;
  firstFailureAt: number;
  lockedUntil: number | null;
};

export type AdminLoginRateLimitOptions = {
  maxFailedAttempts?: number;
  windowMs?: number;
  lockoutMs?: number;
  now?: () => number;
};

const defaultOptions = {
  maxFailedAttempts: 5,
  windowMs: 15 * 60 * 1000,
  lockoutMs: 15 * 60 * 1000,
};

const attempts = new Map<string, AttemptRecord>();

export function adminLoginIdentifier(email: string, ipAddress?: string | null) {
  const normalizedEmail = email.trim().toLowerCase() || 'unknown-email';
  const normalizedIp = ipAddress?.trim() || 'unknown-ip';
  return `${normalizedEmail}:${normalizedIp}`;
}

export function assertAdminLoginAllowed(
  identifier: string,
  options: AdminLoginRateLimitOptions = {},
) {
  const merged = mergeOptions(options);
  const now = merged.now();
  const record = attempts.get(identifier);

  if (!record) {
    return;
  }

  if (record.lockedUntil && record.lockedUntil > now) {
    throw new AppError(429, 'Too many admin login attempts. Try again later.');
  }

  if (record.lockedUntil && record.lockedUntil <= now) {
    attempts.delete(identifier);
  }
}

export function recordAdminLoginFailure(
  identifier: string,
  options: AdminLoginRateLimitOptions = {},
) {
  const merged = mergeOptions(options);
  const now = merged.now();
  const existing = attempts.get(identifier);
  const stale =
    existing && now - existing.firstFailureAt > merged.windowMs;

  const record: AttemptRecord =
    !existing || stale
      ? { failedAttempts: 0, firstFailureAt: now, lockedUntil: null }
      : existing;

  record.failedAttempts += 1;
  record.lockedUntil =
    record.failedAttempts >= merged.maxFailedAttempts
      ? now + merged.lockoutMs
      : null;

  attempts.set(identifier, record);
}

export function recordAdminLoginSuccess(identifier: string) {
  attempts.delete(identifier);
}

export function resetAdminLoginRateLimitForTests() {
  attempts.clear();
}

function mergeOptions(options: AdminLoginRateLimitOptions) {
  return {
    maxFailedAttempts:
      options.maxFailedAttempts ?? defaultOptions.maxFailedAttempts,
    windowMs: options.windowMs ?? defaultOptions.windowMs,
    lockoutMs: options.lockoutMs ?? defaultOptions.lockoutMs,
    now: options.now ?? Date.now,
  };
}
