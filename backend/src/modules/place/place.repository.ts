import { prisma } from '../../config/db';
import { PlaceCreateInput, PlaceUpdateInput } from './place.model';

export type DuplicatePlaceLookupInput = {
  excludeId?: string;
  userId: string;
  name?: string;
  address?: string;
  mapsUrls?: string[];
  latitude?: number | null;
  longitude?: number | null;
};

export type DuplicatePlaceCandidate = {
  id: string;
  name: string;
  address: string;
  mapsUrl: string | null;
  latitude: number | null;
  longitude: number | null;
};

export class PlaceRepository {
  private static readonly duplicateCoordinateWindow = 0.001;

  findAll(options?: {
    userId?: string;
    categoryId?: string;
    sort?: 'rating' | 'createdAt';
    limit?: number;
  }) {
    const { userId, categoryId, sort, limit } = options ?? {};
    return prisma.place.findMany({
      where: {
        ...(userId ? { userId } : {}),
        ...(categoryId ? { categoryId } : {}),
      },
      orderBy: sort === 'rating'
        ? { rating: 'desc' }
        : { createdAt: 'desc' },
      take: limit,
      include: { category: true },
    });
  }

  findById(id: string, userId?: string) {
    return userId ? prisma.place.findFirst({
      where: { id, userId },
      include: { category: true, schedules: true },
    }) : prisma.place.findUnique({
      where: { id },
      include: { category: true, schedules: true },
    });
  }

  create(userId: string, data: PlaceCreateInput) {
    return prisma.place.create({
      data: {
        ...data,
        userId,
        priceRange: data.priceRange ?? '',
        openingHours: data.openingHours ?? '',
      },
      include: { category: true },
    });
  }

  update(id: string, data: PlaceUpdateInput) {
    const normalizedData = {
      ...data,
      priceRange: data.priceRange === null ? '' : data.priceRange,
      openingHours: data.openingHours === null ? '' : data.openingHours,
    };

    return prisma.place.update({
      where: { id },
      data: normalizedData,
      include: { category: true },
    });
  }

  delete(id: string) {
    return prisma.place.delete({ where: { id } });
  }

  async findDuplicateCandidates({
    excludeId,
    userId,
    name,
    address,
    mapsUrls,
    latitude,
    longitude,
  }: DuplicatePlaceLookupInput): Promise<DuplicatePlaceCandidate[]> {
    const orConditions: object[] = [];

    const normalizedMapsUrls = Array.from(
      new Set((mapsUrls ?? []).map((value) => value.trim()).filter(Boolean)),
    );
    if (normalizedMapsUrls.length > 0) {
      orConditions.push({
        mapsUrl: {
          in: normalizedMapsUrls,
        },
      });
    }

    if (name?.trim()) {
      orConditions.push({
        name: {
          equals: name.trim(),
          mode: 'insensitive',
        },
      });
    }

    if (address?.trim()) {
      orConditions.push({
        address: {
          equals: address.trim(),
          mode: 'insensitive',
        },
      });
    }

    if (_hasUsableCoordinates(latitude, longitude)) {
      const coordinateWindow = PlaceRepository.duplicateCoordinateWindow;
      orConditions.push({
        AND: [
          {
            latitude: {
              gte: latitude! - coordinateWindow,
              lte: latitude! + coordinateWindow,
            },
          },
          {
            longitude: {
              gte: longitude! - coordinateWindow,
              lte: longitude! + coordinateWindow,
            },
          },
        ],
      });
    }

    if (orConditions.length == 0) {
      return [];
    }

    return prisma.place.findMany({
      where: {
        userId,
        ...(excludeId ? { NOT: { id: excludeId } } : {}),
        OR: orConditions,
      },
      select: {
        id: true,
        name: true,
        address: true,
        mapsUrl: true,
        latitude: true,
        longitude: true,
      },
      take: 20,
    });
  }
}

export const placeRepository = new PlaceRepository();

function _hasUsableCoordinates(
  latitude?: number | null,
  longitude?: number | null,
) {
  if (latitude == null || longitude == null) {
    return false;
  }

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return false;
  }

  if (latitude < -90 || latitude > 90) {
    return false;
  }

  if (longitude < -180 || longitude > 180) {
    return false;
  }

  return latitude !== 0 || longitude !== 0;
}
