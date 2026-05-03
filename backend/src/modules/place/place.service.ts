import { ConflictError, NotFoundError } from '../../utils/errors';
import { PlaceCreateInput, PlaceUpdateInput } from './place.model';
import {
  DuplicatePlaceCandidate,
  placeRepository,
  PlaceRepository,
} from './place.repository';

type PlaceIdentitySnapshot = {
  name: string;
  address: string;
  mapsUrl?: string | null;
  latitude?: number | null;
  longitude?: number | null;
};

type DuplicateMatch = {
  candidate: DuplicatePlaceCandidate;
  reason: 'maps-url' | 'coordinates' | 'name-address';
};

export class PlaceService {
  constructor(
    private readonly repository: Pick<
      PlaceRepository,
      | 'findAll'
      | 'findById'
      | 'create'
      | 'update'
      | 'delete'
      | 'findDuplicateCandidates'
    > = placeRepository,
  ) {}

  findAll(options?: {
    categoryId?: string;
    sort?: 'rating' | 'createdAt';
    limit?: number;
  }) {
    return this.repository.findAll(options);
  }

  async findById(id: string) {
    const place = await this.repository.findById(id);
    if (!place) {
      throw new NotFoundError('Place not found');
    }
    return place;
  }

  async create(data: PlaceCreateInput) {
    await this.ensureNoDuplicatePlace(data);
    return this.repository.create(data);
  }

  async update(id: string, data: PlaceUpdateInput) {
    const current = await this.findById(id);
    if (_hasIdentityChanges(current, data)) {
      await this.ensureNoDuplicatePlace(_mergeIdentity(current, data), id);
    }
    return this.repository.update(id, data);
  }

  async delete(id: string) {
    await this.findById(id);
    await this.repository.delete(id);
    return { id };
  }

  private async ensureNoDuplicatePlace(
    data: PlaceIdentitySnapshot,
    excludeId?: string,
  ) {
    const mapsUrlCandidates = _mapsUrlCandidates(data.mapsUrl);
    const candidates = await this.repository.findDuplicateCandidates({
      excludeId,
      name: data.name,
      address: data.address,
      mapsUrls: mapsUrlCandidates,
      latitude: data.latitude,
      longitude: data.longitude,
    });

    const duplicate = _findDuplicateMatch(candidates, data);
    if (!duplicate) {
      return;
    }

    throw new ConflictError(
      _duplicatePlaceMessage(duplicate.candidate.name, duplicate.reason),
      {
        duplicatePlaceId: duplicate.candidate.id,
        duplicateReason: duplicate.reason,
      },
    );
  }
}

export const placeService = new PlaceService();

function _findDuplicateMatch(
  candidates: DuplicatePlaceCandidate[],
  input: PlaceIdentitySnapshot,
): DuplicateMatch | null {
  const normalizedName = _normalizeLooseText(input.name);
  const normalizedAddress = _normalizeLooseText(input.address);
  const normalizedMapsUrl = _normalizeMapsUrl(input.mapsUrl);

  for (const candidate of candidates) {
    const candidateMapsUrl = _normalizeMapsUrl(candidate.mapsUrl);
    if (
      normalizedMapsUrl &&
      candidateMapsUrl &&
      normalizedMapsUrl === candidateMapsUrl
    ) {
      return { candidate, reason: 'maps-url' };
    }

    const candidateName = _normalizeLooseText(candidate.name);
    const candidateAddress = _normalizeLooseText(candidate.address);
    const sameName = _areLikelySameName(normalizedName, candidateName);
    const sameAddress = _areLikelySameAddress(
      normalizedAddress,
      candidateAddress,
    );

    if (
      sameName &&
      _hasUsableCoordinates(input.latitude, input.longitude) &&
      _hasUsableCoordinates(candidate.latitude, candidate.longitude) &&
      _distanceInMeters(
        input.latitude!,
        input.longitude!,
        candidate.latitude!,
        candidate.longitude!,
      ) <= 75
    ) {
      return { candidate, reason: 'coordinates' };
    }

    if (sameName && sameAddress) {
      return { candidate, reason: 'name-address' };
    }
  }

  return null;
}

function _hasIdentityChanges(
  current: PlaceIdentitySnapshot,
  update: PlaceUpdateInput,
) {
  return (
    (update.name !== undefined && update.name !== current.name) ||
    (update.address !== undefined && update.address !== current.address) ||
    (update.mapsUrl !== undefined && update.mapsUrl !== current.mapsUrl) ||
    (update.latitude !== undefined && update.latitude !== current.latitude) ||
    (update.longitude !== undefined && update.longitude !== current.longitude)
  );
}

function _mergeIdentity(
  current: PlaceIdentitySnapshot,
  update: PlaceUpdateInput,
): PlaceIdentitySnapshot {
  return {
    name: update.name ?? current.name,
    address: update.address ?? current.address,
    mapsUrl: update.mapsUrl === undefined ? current.mapsUrl : update.mapsUrl,
    latitude: update.latitude === undefined ? current.latitude : update.latitude,
    longitude:
      update.longitude === undefined ? current.longitude : update.longitude,
  };
}

function _normalizeLooseText(value?: string | null) {
  const cleaned = value
    ?.normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');

  return cleaned || null;
}

function _normalizeMapsUrl(value?: string | null) {
  const cleaned = value?.trim();
  if (!cleaned) {
    return null;
  }

  const withScheme = /^https?:\/\//i.test(cleaned) ? cleaned : `https://${cleaned}`;

  try {
    const url = new URL(withScheme);
    if (url.hostname.toLowerCase() === 'ps.app.goo.gl') {
      url.hostname = 'maps.app.goo.gl';
    }

    url.hash = '';
    for (const key of [
      'hl',
      'entry',
      'g_ep',
      'g_st',
      'authuser',
      'utm_source',
      'utm_medium',
      'utm_campaign',
    ]) {
      url.searchParams.delete(key);
    }

    const sortedSearchParams = [...url.searchParams.entries()].sort(([a], [b]) =>
      a.localeCompare(b),
    );
    url.search = '';
    for (const [key, paramValue] of sortedSearchParams) {
      url.searchParams.append(key, paramValue);
    }

    return url.toString().replace(/\/$/, '').toLowerCase();
  } catch {
    return cleaned.toLowerCase();
  }
}

function _mapsUrlCandidates(value?: string | null) {
  const normalized = _normalizeMapsUrl(value);
  const cleaned = value?.trim();
  return Array.from(
    new Set([cleaned, cleaned?.toLowerCase(), normalized].filter(Boolean)),
  ) as string[];
}

function _areLikelySameName(
  first?: string | null,
  second?: string | null,
) {
  if (!first || !second) {
    return false;
  }

  if (first === second) {
    return true;
  }

  if (first.length >= 6 && second.length >= 6) {
    if (first.includes(second) || second.includes(first)) {
      return true;
    }
  }

  const firstTokens = new Set(first.split(' ').filter(Boolean));
  const secondTokens = new Set(second.split(' ').filter(Boolean));
  let overlap = 0;

  for (const token of firstTokens) {
    if (secondTokens.has(token)) {
      overlap += 1;
    }
  }

  const minTokenCount = Math.min(firstTokens.size, secondTokens.size);
  return minTokenCount >= 2 && overlap / minTokenCount >= 0.75;
}

function _areLikelySameAddress(
  first?: string | null,
  second?: string | null,
) {
  if (!first || !second) {
    return false;
  }

  if (first === second) {
    return true;
  }

  if (first.length >= 12 && second.length >= 12) {
    return first.includes(second) || second.includes(first);
  }

  return false;
}

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

function _distanceInMeters(
  firstLatitude: number,
  firstLongitude: number,
  secondLatitude: number,
  secondLongitude: number,
) {
  const earthRadius = 6371000;
  const dLatitude = _toRadians(secondLatitude - firstLatitude);
  const dLongitude = _toRadians(secondLongitude - firstLongitude);
  const latitude1 = _toRadians(firstLatitude);
  const latitude2 = _toRadians(secondLatitude);

  const a =
    Math.sin(dLatitude / 2) * Math.sin(dLatitude / 2) +
    Math.cos(latitude1) *
      Math.cos(latitude2) *
      Math.sin(dLongitude / 2) *
      Math.sin(dLongitude / 2);

  return 2 * earthRadius * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function _toRadians(value: number) {
  return (value * Math.PI) / 180;
}

function _duplicatePlaceMessage(
  name: string,
  reason: DuplicateMatch['reason'],
) {
  switch (reason) {
    case 'maps-url':
      return `Dia diem "${name}" da ton tai (trung lien ket Google Maps)`;
    case 'coordinates':
      return `Dia diem "${name}" co ve da ton tai (trung ten va vi tri ban do)`;
    case 'name-address':
      return `Dia diem "${name}" da ton tai (trung ten va dia chi)`;
  }
}
