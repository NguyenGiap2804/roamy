import {
  ImageAssetStatus,
  ImageStorageKind,
  Prisma,
  ScheduleStatus,
  SystemEventSeverity,
} from '@prisma/client';

import { prisma } from '../../config/db';

export type AdminListOptions = {
  q?: string;
  page?: number;
  limit?: number;
  status?: string;
  type?: string;
  severity?: string;
  categoryId?: string;
  imageStatus?: string;
  minRating?: number;
  from?: string;
  to?: string;
};

export type AdminListResult<T> = {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  items: T[];
};

export class AdminService {
  async overview() {
    const now = new Date();
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);
    const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const [
      totalPlaces,
      totalCategories,
      totalSchedules,
      errorsToday,
      responseAggregate,
      uploadTotal,
      uploadSuccess,
      activeDevices,
      latestActivity,
      latestErrors,
      latestPlaces,
      slowRequests,
      failedUploads,
    ] = await Promise.all([
      prisma.place.count(),
      prisma.category.count(),
      prisma.schedule.count(),
      prisma.apiErrorLog.count({ where: { createdAt: { gte: today } } }),
      prisma.apiRequestLog.aggregate({
        where: { createdAt: { gte: last24h } },
        _avg: { durationMs: true },
      }),
      prisma.imageAsset.count({ where: { createdAt: { gte: last24h } } }),
      prisma.imageAsset.count({
        where: { createdAt: { gte: last24h }, status: 'SUCCESS' },
      }),
      prisma.systemEvent.findMany({
        where: { createdAt: { gte: last24h }, deviceId: { not: null } },
        distinct: ['deviceId'],
        select: { deviceId: true },
      }),
      prisma.systemEvent.findMany({
        orderBy: { createdAt: 'desc' },
        take: 12,
      }),
      prisma.apiErrorLog.findMany({
        orderBy: { createdAt: 'desc' },
        take: 8,
      }),
      prisma.place.findMany({
        orderBy: { createdAt: 'desc' },
        take: 8,
        include: { category: true },
      }),
      prisma.apiRequestLog.findMany({
        where: { createdAt: { gte: last24h }, durationMs: { gte: 1000 } },
        orderBy: { createdAt: 'desc' },
        take: 8,
      }),
      prisma.imageAsset.findMany({
        where: { createdAt: { gte: last24h }, status: 'FAILED' },
        orderBy: { createdAt: 'desc' },
        take: 8,
      }),
    ]);

    const uploadSuccessRate =
      uploadTotal === 0 ? 100 : Math.round((uploadSuccess / uploadTotal) * 100);

    return {
      kpis: {
        totalPlaces,
        totalCategories,
        totalSchedules,
        errorsToday,
        averageResponseMs: Math.round(responseAggregate._avg.durationMs ?? 0),
        uploadSuccessRate,
        activeDevices: activeDevices.length,
      },
      latestActivity,
      latestErrors,
      latestPlaces,
      attention: {
        latestErrors,
        slowRequests,
        failedUploads,
        cloudinaryMissing: !hasCloudinaryConfig(),
      },
    };
  }

  async health() {
    const startedAt = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    const databaseLatencyMs = Date.now() - startedAt;

    return {
      backend: {
        status: 'online',
        uptimeSeconds: Math.round(process.uptime()),
        environment: process.env.NODE_ENV || 'development',
      },
      database: {
        status: 'online',
        latencyMs: databaseLatencyMs,
      },
      cloudinary: {
        status: hasCloudinaryConfig() ? 'configured' : 'missing-config',
      },
      admin: {
        renderUrl: process.env.PUBLIC_BASE_URL || null,
      },
    };
  }

  listPlaces(options: AdminListOptions) {
    const { skip, take, page, limit } = pagination(options);
    const and: Prisma.PlaceWhereInput[] = [];
    const q = normalizedQuery(options.q);

    if (q) {
      and.push({
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { address: { contains: q, mode: 'insensitive' } },
          { category: { name: { contains: q, mode: 'insensitive' } } },
        ],
      });
    }

    if (options.categoryId) {
      and.push({ categoryId: options.categoryId });
    }

    if (Number.isFinite(options.minRating)) {
      and.push({ rating: { gte: options.minRating } });
    }

    if (options.imageStatus === 'with-image') {
      and.push({
        AND: [{ imageUrl: { not: null } }, { imageUrl: { not: '' } }],
      });
    }

    if (options.imageStatus === 'without-image') {
      and.push({ OR: [{ imageUrl: null }, { imageUrl: '' }] });
    }

    const createdAt = dateTimeFilter(options);
    if (createdAt) {
      and.push({ createdAt });
    }

    const where = and.length > 0 ? { AND: and } : undefined;

    return this.withTotal(
      prisma.place.count({ where }),
      prisma.place.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: { category: true, schedules: true },
      }),
      page,
      limit,
    );
  }

  listCategories(options: AdminListOptions) {
    const { skip, take, page, limit } = pagination(options);
    const and: Prisma.CategoryWhereInput[] = [];
    const q = normalizedQuery(options.q);

    if (q) {
      and.push({ name: { contains: q, mode: 'insensitive' } });
    }

    const createdAt = dateTimeFilter(options);
    if (createdAt) {
      and.push({ createdAt });
    }

    const where = and.length > 0 ? { AND: and } : undefined;

    return this.withTotal(
      prisma.category.count({ where }),
      prisma.category.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'asc' },
        include: { _count: { select: { places: true } } },
      }),
      page,
      limit,
    );
  }

  listSchedules(options: AdminListOptions) {
    const { skip, take, page, limit } = pagination(options);
    const and: Prisma.ScheduleWhereInput[] = [];
    const q = normalizedQuery(options.q);

    if (q) {
      and.push({
        OR: [
          { place: { name: { contains: q, mode: 'insensitive' } } },
          { place: { address: { contains: q, mode: 'insensitive' } } },
        ],
      });
    }

    if (isScheduleStatus(options.status)) {
      and.push({ status: options.status });
    }

    const date = dateTimeFilter(options);
    if (date) {
      and.push({ date });
    }

    const where = and.length > 0 ? { AND: and } : undefined;

    return this.withTotal(
      prisma.schedule.count({ where }),
      prisma.schedule.findMany({
        where,
        skip,
        take,
        orderBy: [{ date: 'desc' }, { time: 'asc' }],
        include: { place: { include: { category: true } } },
      }),
      page,
      limit,
    );
  }

  listActivity(options: AdminListOptions) {
    const { skip, take, page, limit } = pagination(options);
    const and: Prisma.SystemEventWhereInput[] = [];
    const q = normalizedQuery(options.q);

    if (options.type) {
      and.push({ type: options.type });
    }

    if (isSystemEventSeverity(options.severity)) {
      and.push({ severity: options.severity });
    }

    if (q) {
      and.push({
        OR: [
          { type: { contains: q, mode: 'insensitive' } },
          { action: { contains: q, mode: 'insensitive' } },
          { message: { contains: q, mode: 'insensitive' } },
          { deviceId: { contains: q, mode: 'insensitive' } },
        ],
      });
    }

    const createdAt = dateTimeFilter(options);
    if (createdAt) {
      and.push({ createdAt });
    }

    const where = and.length > 0 ? { AND: and } : undefined;

    return this.withTotal(
      prisma.systemEvent.count({ where }),
      prisma.systemEvent.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
      page,
      limit,
    );
  }

  listErrors(options: AdminListOptions) {
    const { skip, take, page, limit } = pagination(options);
    const and: Prisma.ApiErrorLogWhereInput[] = [];
    const q = normalizedQuery(options.q);

    if (options.status && Number.isFinite(Number(options.status))) {
      and.push({ statusCode: Number(options.status) });
    }

    if (q) {
      and.push({
        OR: [
          { path: { contains: q, mode: 'insensitive' } },
          { message: { contains: q, mode: 'insensitive' } },
          { name: { contains: q, mode: 'insensitive' } },
          { deviceId: { contains: q, mode: 'insensitive' } },
        ],
      });
    }

    const createdAt = dateTimeFilter(options);
    if (createdAt) {
      and.push({ createdAt });
    }

    const where = and.length > 0 ? { AND: and } : undefined;

    return this.withTotal(
      prisma.apiErrorLog.count({ where }),
      prisma.apiErrorLog.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
      page,
      limit,
    );
  }

  listRequests(options: AdminListOptions) {
    const { skip, take, page, limit } = pagination(options);
    const and: Prisma.ApiRequestLogWhereInput[] = [];
    const q = normalizedQuery(options.q);

    if (isResponseStatus(options.status)) {
      and.push({ responseStatus: options.status });
    }

    if (q) {
      and.push({
        OR: [
          { path: { contains: q, mode: 'insensitive' } },
          { method: { contains: q, mode: 'insensitive' } },
          { deviceId: { contains: q, mode: 'insensitive' } },
        ],
      });
    }

    const createdAt = dateTimeFilter(options);
    if (createdAt) {
      and.push({ createdAt });
    }

    const where = and.length > 0 ? { AND: and } : undefined;

    return this.withTotal(
      prisma.apiRequestLog.count({ where }),
      prisma.apiRequestLog.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
      page,
      limit,
    );
  }

  listUploads(options: AdminListOptions) {
    const { skip, take, page, limit } = pagination(options);
    const and: Prisma.ImageAssetWhereInput[] = [];
    const q = normalizedQuery(options.q);
    const status = options.imageStatus ?? options.status;

    if (isImageAssetStatus(status)) {
      and.push({ status });
    }

    if (isImageStorageKind(options.type)) {
      and.push({ storage: options.type });
    }

    if (q) {
      and.push({
        OR: [
          { url: { contains: q, mode: 'insensitive' } },
          { originalName: { contains: q, mode: 'insensitive' } },
          { deviceId: { contains: q, mode: 'insensitive' } },
        ],
      });
    }

    const createdAt = dateTimeFilter(options);
    if (createdAt) {
      and.push({ createdAt });
    }

    const where = and.length > 0 ? { AND: and } : undefined;

    return this.withTotal(
      prisma.imageAsset.count({ where }),
      prisma.imageAsset.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
      page,
      limit,
    );
  }

  private async withTotal<T>(
    totalPromise: Promise<number>,
    itemsPromise: Promise<T[]>,
    page: number,
    limit: number,
  ): Promise<AdminListResult<T>> {
    const [total, items] = await Promise.all([totalPromise, itemsPromise]);
    return {
      total,
      page,
      limit,
      totalPages: total === 0 ? 0 : Math.ceil(total / limit),
      items,
    };
  }
}

export const adminService = new AdminService();

function pagination(options: AdminListOptions) {
  const page = Math.max(1, Number(options.page) || 1);
  const limit = Math.min(100, Math.max(1, Number(options.limit) || 25));
  return { skip: (page - 1) * limit, take: limit, page, limit };
}

function normalizedQuery(value?: string) {
  const q = value?.trim();
  return q ? q : undefined;
}

function dateTimeFilter(options: AdminListOptions) {
  const gte = parseBoundaryDate(options.from, 'start');
  const lte = parseBoundaryDate(options.to, 'end');

  if (!gte && !lte) {
    return undefined;
  }

  return {
    ...(gte ? { gte } : {}),
    ...(lte ? { lte } : {}),
  };
}

function parseBoundaryDate(value: string | undefined, boundary: 'start' | 'end') {
  if (!value) {
    return undefined;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }

  const isDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(trimmed);
  const parsed = new Date(
    isDateOnly && boundary === 'end'
      ? `${trimmed}T23:59:59.999Z`
      : isDateOnly
      ? `${trimmed}T00:00:00.000Z`
      : trimmed,
  );

  return Number.isNaN(parsed.getTime()) ? undefined : parsed;
}

function isSystemEventSeverity(
  value?: string,
): value is SystemEventSeverity {
  return Boolean(
    value &&
      Object.values(SystemEventSeverity).includes(value as SystemEventSeverity),
  );
}

function isScheduleStatus(value?: string): value is ScheduleStatus {
  return Boolean(
    value && Object.values(ScheduleStatus).includes(value as ScheduleStatus),
  );
}

function isImageAssetStatus(value?: string): value is ImageAssetStatus {
  return Boolean(
    value && Object.values(ImageAssetStatus).includes(value as ImageAssetStatus),
  );
}

function isImageStorageKind(value?: string): value is ImageStorageKind {
  return Boolean(
    value && Object.values(ImageStorageKind).includes(value as ImageStorageKind),
  );
}

function isResponseStatus(value?: string): value is 'OK' | 'WARN' | 'ERROR' {
  return value === 'OK' || value === 'WARN' || value === 'ERROR';
}

function hasCloudinaryConfig() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME &&
      process.env.CLOUDINARY_API_KEY &&
      process.env.CLOUDINARY_API_SECRET,
  );
}
