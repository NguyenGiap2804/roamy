import assert from 'node:assert/strict';
import test from 'node:test';

import {
  retentionCutoff,
  retentionPolicyFromEnv,
} from '../src/modules/maintenance/retention.service';

test('retention policy uses safe defaults when env is missing', () => {
  assert.deepEqual(retentionPolicyFromEnv({}), {
    requestLogDays: 30,
    errorLogDays: 90,
    systemEventDays: 90,
    imageAssetDays: 180,
  });
});

test('retention policy ignores invalid env values', () => {
  assert.deepEqual(
    retentionPolicyFromEnv({
      REQUEST_LOG_RETENTION_DAYS: '0',
      ERROR_LOG_RETENTION_DAYS: '-7',
      SYSTEM_EVENT_RETENTION_DAYS: 'abc',
      IMAGE_ASSET_RETENTION_DAYS: '14.5',
    }),
    {
      requestLogDays: 30,
      errorLogDays: 90,
      systemEventDays: 90,
      imageAssetDays: 180,
    },
  );
});

test('retention policy reads positive day values from env', () => {
  assert.deepEqual(
    retentionPolicyFromEnv({
      REQUEST_LOG_RETENTION_DAYS: '14',
      ERROR_LOG_RETENTION_DAYS: '45',
      SYSTEM_EVENT_RETENTION_DAYS: '60',
      IMAGE_ASSET_RETENTION_DAYS: '365',
    }),
    {
      requestLogDays: 14,
      errorLogDays: 45,
      systemEventDays: 60,
      imageAssetDays: 365,
    },
  );
});

test('retention cutoff subtracts full days from current time', () => {
  const now = new Date('2026-05-24T12:00:00.000Z');
  assert.equal(
    retentionCutoff(3, now).toISOString(),
    '2026-05-21T12:00:00.000Z',
  );
});
