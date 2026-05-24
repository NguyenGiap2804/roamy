import { prisma } from '../../config/db';

export type ImageHealthStatus = 'OK' | 'BROKEN' | 'MISSING';

export type ImageHealthItem = {
  placeId: string;
  name: string;
  address: string;
  imageUrl: string | null;
  status: ImageHealthStatus;
  statusCode?: number;
  contentType?: string;
  errorMessage?: string;
  checkedAt: string;
};

export type ImageHealthReport = {
  total: number;
  ok: number;
  broken: number;
  missing: number;
  checkedAt: string;
  items: ImageHealthItem[];
};

type CheckImagesOptions = {
  limit?: number;
  q?: string;
};

export class AdminImageHealthService {
  async check(options: CheckImagesOptions = {}): Promise<ImageHealthReport> {
    const limit = Math.min(200, Math.max(1, Number(options.limit) || 100));
    const q = options.q?.trim();
    const places = await prisma.place.findMany({
      where: q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' } },
              { address: { contains: q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        name: true,
        address: true,
        imageUrl: true,
      },
    });

    const items = await mapWithConcurrency(places, 6, async (place) => {
      const result = await checkImageUrl(place.imageUrl);
      return {
        placeId: place.id,
        name: place.name,
        address: place.address,
        imageUrl: place.imageUrl,
        checkedAt: new Date().toISOString(),
        ...result,
      };
    });

    return {
      total: items.length,
      ok: items.filter((item) => item.status === 'OK').length,
      broken: items.filter((item) => item.status === 'BROKEN').length,
      missing: items.filter((item) => item.status === 'MISSING').length,
      checkedAt: new Date().toISOString(),
      items,
    };
  }
}

export const adminImageHealthService = new AdminImageHealthService();

export async function checkImageUrl(
  imageUrl?: string | null,
): Promise<Pick<ImageHealthItem, 'status' | 'statusCode' | 'contentType' | 'errorMessage'>> {
  const cleaned = imageUrl?.trim();
  if (!cleaned) {
    return { status: 'MISSING', errorMessage: 'No image URL saved' };
  }

  if (!/^https?:\/\//i.test(cleaned)) {
    return { status: 'BROKEN', errorMessage: 'Image URL is not HTTP/HTTPS' };
  }

  try {
    const response = await probeImage(cleaned);
    const contentType = response.headers.get('content-type') ?? undefined;
    const looksLikeImage = !contentType || contentType.startsWith('image/');

    return {
      status: response.ok && looksLikeImage ? 'OK' : 'BROKEN',
      statusCode: response.status,
      contentType,
      errorMessage:
        response.ok && looksLikeImage
          ? undefined
          : contentType && !looksLikeImage
          ? `Unexpected content type: ${contentType}`
          : `Image returned HTTP ${response.status}`,
    };
  } catch (error) {
    return {
      status: 'BROKEN',
      errorMessage:
        error instanceof Error ? error.message : 'Image check failed',
    };
  }
}

async function probeImage(url: string) {
  const headResponse = await fetchWithTimeout(url, { method: 'HEAD' });
  if (headResponse.ok || ![403, 405].includes(headResponse.status)) {
    return headResponse;
  }

  return fetchWithTimeout(url, {
    method: 'GET',
    headers: { Range: 'bytes=0-0' },
  });
}

async function fetchWithTimeout(url: string, init: RequestInit) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    return await fetch(url, {
      ...init,
      redirect: 'follow',
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  mapper: (item: T) => Promise<R>,
) {
  const results = new Array<R>(items.length);
  let nextIndex = 0;

  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, async () => {
      while (nextIndex < items.length) {
        const currentIndex = nextIndex;
        nextIndex += 1;
        results[currentIndex] = await mapper(items[currentIndex]);
      }
    }),
  );

  return results;
}
