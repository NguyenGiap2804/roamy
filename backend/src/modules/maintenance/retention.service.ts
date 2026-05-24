import { prisma } from '../../config/db';

export type RetentionPolicy = {
  requestLogDays: number;
  errorLogDays: number;
  systemEventDays: number;
  imageAssetDays: number;
};

export type RetentionPreview = {
  policy: RetentionPolicy;
  cutoffs: RetentionCutoffs;
  counts: RetentionCounts;
};

export type RetentionRunResult = RetentionPreview & {
  deleted: RetentionCounts;
};

type RetentionCutoffs = {
  apiRequestLogs: string;
  apiErrorLogs: string;
  systemEvents: string;
  imageAssets: string;
};

type RetentionCounts = {
  apiRequestLogs: number;
  apiErrorLogs: number;
  systemEvents: number;
  imageAssets: number;
};

const defaults: RetentionPolicy = {
  requestLogDays: 30,
  errorLogDays: 90,
  systemEventDays: 90,
  imageAssetDays: 180,
};

export class RetentionService {
  async preview(
    policy = retentionPolicyFromEnv(),
    now = new Date(),
  ): Promise<RetentionPreview> {
    const cutoffs = retentionCutoffs(policy, now);
    const [apiRequestLogs, apiErrorLogs, systemEvents, imageAssets] =
      await Promise.all([
        prisma.apiRequestLog.count({
          where: { createdAt: { lt: new Date(cutoffs.apiRequestLogs) } },
        }),
        prisma.apiErrorLog.count({
          where: { createdAt: { lt: new Date(cutoffs.apiErrorLogs) } },
        }),
        prisma.systemEvent.count({
          where: { createdAt: { lt: new Date(cutoffs.systemEvents) } },
        }),
        prisma.imageAsset.count({
          where: { createdAt: { lt: new Date(cutoffs.imageAssets) } },
        }),
      ]);

    return {
      policy,
      cutoffs,
      counts: {
        apiRequestLogs,
        apiErrorLogs,
        systemEvents,
        imageAssets,
      },
    };
  }

  async run(
    policy = retentionPolicyFromEnv(),
    now = new Date(),
  ): Promise<RetentionRunResult> {
    const preview = await this.preview(policy, now);
    const [apiRequestLogs, apiErrorLogs, systemEvents, imageAssets] =
      await Promise.all([
        prisma.apiRequestLog.deleteMany({
          where: { createdAt: { lt: new Date(preview.cutoffs.apiRequestLogs) } },
        }),
        prisma.apiErrorLog.deleteMany({
          where: { createdAt: { lt: new Date(preview.cutoffs.apiErrorLogs) } },
        }),
        prisma.systemEvent.deleteMany({
          where: { createdAt: { lt: new Date(preview.cutoffs.systemEvents) } },
        }),
        prisma.imageAsset.deleteMany({
          where: { createdAt: { lt: new Date(preview.cutoffs.imageAssets) } },
        }),
      ]);

    return {
      ...preview,
      deleted: {
        apiRequestLogs: apiRequestLogs.count,
        apiErrorLogs: apiErrorLogs.count,
        systemEvents: systemEvents.count,
        imageAssets: imageAssets.count,
      },
    };
  }
}

export const retentionService = new RetentionService();

export function retentionPolicyFromEnv(
  env: Record<string, string | undefined> = process.env,
): RetentionPolicy {
  return {
    requestLogDays: positiveInt(
      env.REQUEST_LOG_RETENTION_DAYS,
      defaults.requestLogDays,
    ),
    errorLogDays: positiveInt(
      env.ERROR_LOG_RETENTION_DAYS,
      defaults.errorLogDays,
    ),
    systemEventDays: positiveInt(
      env.SYSTEM_EVENT_RETENTION_DAYS,
      defaults.systemEventDays,
    ),
    imageAssetDays: positiveInt(
      env.IMAGE_ASSET_RETENTION_DAYS,
      defaults.imageAssetDays,
    ),
  };
}

export function retentionCutoffs(policy: RetentionPolicy, now = new Date()) {
  return {
    apiRequestLogs: retentionCutoff(policy.requestLogDays, now).toISOString(),
    apiErrorLogs: retentionCutoff(policy.errorLogDays, now).toISOString(),
    systemEvents: retentionCutoff(policy.systemEventDays, now).toISOString(),
    imageAssets: retentionCutoff(policy.imageAssetDays, now).toISOString(),
  };
}

export function retentionCutoff(days: number, now = new Date()) {
  return new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
}

function positiveInt(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}
