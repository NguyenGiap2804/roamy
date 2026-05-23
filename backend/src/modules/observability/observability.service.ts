import {
  ImageAssetStatus,
  ImageStorageKind,
  Prisma,
  SystemEventSeverity,
} from '@prisma/client';

import { prisma } from '../../config/db';

type JsonInput = Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput;

export type SystemEventInput = {
  type: string;
  action?: string | null;
  resourceType?: string | null;
  resourceId?: string | null;
  screen?: string | null;
  message?: string | null;
  severity?: SystemEventSeverity;
  deviceId?: string | null;
  requestId?: string | null;
  metadata?: unknown;
  occurredAt?: Date;
};

export type ApiRequestInput = {
  requestId: string;
  method: string;
  path: string;
  statusCode: number;
  durationMs: number;
  deviceId?: string | null;
  userAgent?: string | null;
  ipAddress?: string | null;
  query?: unknown;
};

export type ApiErrorInput = {
  requestId?: string | null;
  method: string;
  path: string;
  statusCode: number;
  name: string;
  message: string;
  details?: unknown;
  deviceId?: string | null;
};

export type ImageAssetInput = {
  url: string;
  storage: ImageStorageKind;
  status?: ImageAssetStatus;
  mimeType?: string | null;
  sizeBytes?: number | null;
  originalName?: string | null;
  deviceId?: string | null;
  requestId?: string | null;
  errorMessage?: string | null;
};

export class ObservabilityService {
  recordSystemEvent(input: SystemEventInput) {
    return this.safeWrite('recordSystemEvent', () =>
      prisma.systemEvent.create({
        data: {
          type: input.type,
          action: input.action ?? null,
          resourceType: input.resourceType ?? null,
          resourceId: input.resourceId ?? null,
          screen: input.screen ?? null,
          message: input.message ?? null,
          severity: input.severity ?? SystemEventSeverity.INFO,
          deviceId: input.deviceId ?? null,
          requestId: input.requestId ?? null,
          metadata: toJsonInput(input.metadata),
          occurredAt: input.occurredAt ?? new Date(),
        },
      }),
    );
  }

  recordApiRequest(input: ApiRequestInput) {
    return this.safeWrite('recordApiRequest', () =>
      prisma.apiRequestLog.create({
        data: {
          requestId: input.requestId,
          method: input.method,
          path: input.path,
          statusCode: input.statusCode,
          durationMs: input.durationMs,
          deviceId: input.deviceId ?? null,
          userAgent: input.userAgent ?? null,
          ipAddress: input.ipAddress ?? null,
          query: toJsonInput(input.query),
          responseStatus: input.statusCode >= 500
            ? 'ERROR'
            : input.statusCode >= 400
            ? 'WARN'
            : 'OK',
        },
      }),
    );
  }

  recordApiError(input: ApiErrorInput) {
    return this.safeWrite('recordApiError', () =>
      prisma.apiErrorLog.create({
        data: {
          requestId: input.requestId ?? null,
          method: input.method,
          path: input.path,
          statusCode: input.statusCode,
          name: input.name,
          message: input.message,
          details: toJsonInput(input.details),
          deviceId: input.deviceId ?? null,
        },
      }),
    );
  }

  recordImageAsset(input: ImageAssetInput) {
    return this.safeWrite('recordImageAsset', () =>
      prisma.imageAsset.create({
        data: {
          url: input.url,
          storage: input.storage,
          status: input.status ?? ImageAssetStatus.SUCCESS,
          mimeType: input.mimeType ?? null,
          sizeBytes: input.sizeBytes ?? null,
          originalName: input.originalName ?? null,
          deviceId: input.deviceId ?? null,
          requestId: input.requestId ?? null,
          errorMessage: input.errorMessage ?? null,
        },
      }),
    );
  }

  private async safeWrite<T>(label: string, operation: () => Promise<T>) {
    try {
      return await operation();
    } catch (error) {
      if (
        process.env.NODE_ENV === 'production' ||
        process.env.OBSERVABILITY_DEBUG === 'true'
      ) {
        console.error(`[Roamy Observability] ${label} failed`, error);
      }
      return null;
    }
  }
}

export const observabilityService = new ObservabilityService();

export function toJsonInput(value: unknown): JsonInput {
  if (value === undefined || value === null) {
    return Prisma.JsonNull;
  }

  return JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue;
}

export function sanitizeForLog(value: unknown): unknown {
  if (value == null) {
    return null;
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeForLog(item));
  }

  if (typeof value === 'object') {
    const source = value as Record<string, unknown>;
    const output: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(source)) {
      if (isSensitiveKey(key)) {
        output[key] = '[redacted]';
      } else {
        output[key] = sanitizeForLog(item);
      }
    }
    return output;
  }

  return value;
}

function isSensitiveKey(key: string) {
  const normalized = key.toLowerCase();
  return (
    normalized.includes('password') ||
    normalized.includes('secret') ||
    normalized.includes('token') ||
    normalized.includes('database_url') ||
    normalized.includes('api_key') ||
    normalized.includes('authorization')
  );
}
