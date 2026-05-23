import { Prisma } from '@prisma/client';

import { prisma } from '../../config/db';

export type AdminListOptions = {
  q?: string;
  page?: number;
  limit?: number;
  status?: string;
  type?: string;
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
    const { skip, take } = pagination(options);
    const q = normalizedQuery(options.q);
    const where: Prisma.PlaceWhereInput | undefined = q
      ? {
          OR: [
            { name: { contains: q, mode: 'insensitive' } },
            { address: { contains: q, mode: 'insensitive' } },
            { category: { name: { contains: q, mode: 'insensitive' } } },
          ],
        }
      : undefined;

    return this.withTotal(
      prisma.place.count({ where }),
      prisma.place.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: { category: true, schedules: true },
      }),
    );
  }

  listCategories(options: AdminListOptions) {
    const { skip, take } = pagination(options);
    const q = normalizedQuery(options.q);
    const where: Prisma.CategoryWhereInput | undefined = q
      ? { name: { contains: q, mode: 'insensitive' } }
      : undefined;

    return this.withTotal(
      prisma.category.count({ where }),
      prisma.category.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'asc' },
        include: { _count: { select: { places: true } } },
      }),
    );
  }

  listSchedules(options: AdminListOptions) {
    const { skip, take } = pagination(options);
    const q = normalizedQuery(options.q);
    const where: Prisma.ScheduleWhereInput | undefined = q
      ? {
          OR: [
            { place: { name: { contains: q, mode: 'insensitive' } } },
            { place: { address: { contains: q, mode: 'insensitive' } } },
          ],
        }
      : undefined;

    return this.withTotal(
      prisma.schedule.count({ where }),
      prisma.schedule.findMany({
        where,
        skip,
        take,
        orderBy: [{ date: 'desc' }, { time: 'asc' }],
        include: { place: { include: { category: true } } },
      }),
    );
  }

  listActivity(options: AdminListOptions) {
    const { skip, take } = pagination(options);
    const q = normalizedQuery(options.q);
    const where: Prisma.SystemEventWhereInput = {
      ...(options.type ? { type: options.type } : {}),
      ...(q
        ? {
            OR: [
              { type: { contains: q, mode: 'insensitive' } },
              { action: { contains: q, mode: 'insensitive' } },
              { message: { contains: q, mode: 'insensitive' } },
              { deviceId: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    return this.withTotal(
      prisma.systemEvent.count({ where }),
      prisma.systemEvent.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
    );
  }

  listErrors(options: AdminListOptions) {
    const { skip, take } = pagination(options);
    const q = normalizedQuery(options.q);
    const where: Prisma.ApiErrorLogWhereInput | undefined = q
      ? {
          OR: [
            { path: { contains: q, mode: 'insensitive' } },
            { message: { contains: q, mode: 'insensitive' } },
            { name: { contains: q, mode: 'insensitive' } },
            { deviceId: { contains: q, mode: 'insensitive' } },
          ],
        }
      : undefined;

    return this.withTotal(
      prisma.apiErrorLog.count({ where }),
      prisma.apiErrorLog.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
    );
  }

  listRequests(options: AdminListOptions) {
    const { skip, take } = pagination(options);
    const q = normalizedQuery(options.q);
    const where: Prisma.ApiRequestLogWhereInput = {
      ...(options.status ? { responseStatus: options.status } : {}),
      ...(q
        ? {
            OR: [
              { path: { contains: q, mode: 'insensitive' } },
              { method: { contains: q, mode: 'insensitive' } },
              { deviceId: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    return this.withTotal(
      prisma.apiRequestLog.count({ where }),
      prisma.apiRequestLog.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
    );
  }

  listUploads(options: AdminListOptions) {
    const { skip, take } = pagination(options);
    const q = normalizedQuery(options.q);
    const where: Prisma.ImageAssetWhereInput = {
      ...(options.status ? { status: options.status as never } : {}),
      ...(q
        ? {
            OR: [
              { url: { contains: q, mode: 'insensitive' } },
              { originalName: { contains: q, mode: 'insensitive' } },
              { deviceId: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    return this.withTotal(
      prisma.imageAsset.count({ where }),
      prisma.imageAsset.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
    );
  }

  private async withTotal<T>(totalPromise: Promise<number>, itemsPromise: Promise<T[]>) {
    const [total, items] = await Promise.all([totalPromise, itemsPromise]);
    return { total, items };
  }
}

export const adminService = new AdminService();

function pagination(options: AdminListOptions) {
  const page = Math.max(1, Number(options.page) || 1);
  const take = Math.min(100, Math.max(1, Number(options.limit) || 25));
  return { skip: (page - 1) * take, take };
}

function normalizedQuery(value?: string) {
  const q = value?.trim();
  return q ? q : undefined;
}

function hasCloudinaryConfig() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME &&
      process.env.CLOUDINARY_API_KEY &&
      process.env.CLOUDINARY_API_SECRET,
  );
}
