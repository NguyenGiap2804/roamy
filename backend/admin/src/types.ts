export type ApiEnvelope<T> = {
  data: T;
  message: string;
  status: number;
};

export type AdminSession = {
  token: string;
  admin: {
    email: string;
    name: string;
  };
};

export type Category = {
  id: string;
  userId: string;
  name: string;
  icon: string;
  createdAt: string;
  user?: UserSummary | null;
  _count?: { places: number };
};

export type Place = {
  id: string;
  userId: string;
  name: string;
  categoryId: string;
  address: string;
  priceRange: string;
  openingHours: string;
  phone?: string | null;
  website?: string | null;
  mapsUrl?: string | null;
  note?: string | null;
  imageUrl?: string | null;
  rating: number;
  latitude?: number | null;
  longitude?: number | null;
  createdAt: string;
  user?: UserSummary | null;
  category?: Category | null;
  schedules?: Schedule[];
};

export type Schedule = {
  id: string;
  userId: string;
  placeId: string;
  date: string;
  time: string;
  status: 'UPCOMING' | 'DONE' | 'CANCELLED';
  hasReminder: boolean;
  createdAt: string;
  user?: UserSummary | null;
  place?: Place | null;
};

export type UserSummary = {
  id: string;
  email: string;
  name: string;
};

export type AdminUser = UserSummary & {
  avatarUrl?: string | null;
  emailVerifiedAt?: string | null;
  lastLoginAt?: string | null;
  createdAt: string;
  accounts: Array<{ provider: 'PASSWORD' | 'GOOGLE'; createdAt: string }>;
  _count: {
    categories: number;
    places: number;
    schedules: number;
  };
};

export type SystemEvent = {
  id: string;
  type: string;
  action?: string | null;
  resourceType?: string | null;
  resourceId?: string | null;
  screen?: string | null;
  message?: string | null;
  severity: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
  deviceId?: string | null;
  user?: UserSummary | null;
  requestId?: string | null;
  metadata?: unknown;
  occurredAt: string;
  createdAt: string;
};

export type ApiErrorLog = {
  id: string;
  requestId?: string | null;
  method: string;
  path: string;
  statusCode: number;
  name: string;
  message: string;
  details?: unknown;
  deviceId?: string | null;
  user?: UserSummary | null;
  createdAt: string;
};

export type ApiRequestLog = {
  id: string;
  requestId: string;
  method: string;
  path: string;
  statusCode: number;
  durationMs: number;
  deviceId?: string | null;
  user?: UserSummary | null;
  userAgent?: string | null;
  ipAddress?: string | null;
  query?: unknown;
  responseStatus: 'OK' | 'WARN' | 'ERROR';
  createdAt: string;
};

export type ImageAsset = {
  id: string;
  url: string;
  storage: 'CLOUDINARY' | 'LOCAL' | 'UNCONFIGURED';
  status: 'SUCCESS' | 'FAILED';
  mimeType?: string | null;
  sizeBytes?: number | null;
  originalName?: string | null;
  deviceId?: string | null;
  user?: UserSummary | null;
  requestId?: string | null;
  errorMessage?: string | null;
  createdAt: string;
};

export type ImageHealthItem = {
  placeId: string;
  name: string;
  address: string;
  imageUrl?: string | null;
  status: 'OK' | 'BROKEN' | 'MISSING';
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

export type RetentionPolicy = {
  requestLogDays: number;
  errorLogDays: number;
  systemEventDays: number;
  imageAssetDays: number;
};

export type RetentionCounts = {
  apiRequestLogs: number;
  apiErrorLogs: number;
  systemEvents: number;
  imageAssets: number;
};

export type RetentionPreview = {
  policy: RetentionPolicy;
  cutoffs: Record<keyof RetentionCounts, string>;
  counts: RetentionCounts;
};

export type RetentionRunResult = RetentionPreview & {
  deleted: RetentionCounts;
};

export type ListResponse<T> = {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  items: T[];
};

export type Overview = {
  kpis: {
    totalPlaces: number;
    totalCategories: number;
    totalSchedules: number;
    totalUsers: number;
    errorsToday: number;
    averageResponseMs: number;
    uploadSuccessRate: number;
    activeDevices: number;
  };
  latestActivity: SystemEvent[];
  latestErrors: ApiErrorLog[];
  latestPlaces: Place[];
  attention?: {
    latestErrors: ApiErrorLog[];
    slowRequests: ApiRequestLog[];
    failedUploads: ImageAsset[];
    cloudinaryMissing: boolean;
  };
};

export type Health = {
  backend: {
    status: string;
    uptimeSeconds: number;
    environment: string;
  };
  database: {
    status: string;
    latencyMs: number;
  };
  cloudinary: {
    status: string;
  };
  admin: {
    renderUrl?: string | null;
  };
};

export type PlaceUpdatePayload = Partial<{
  name: string;
  categoryId: string;
  address: string;
  priceRange: string | null;
  openingHours: string | null;
  phone: string | null;
  website: string | null;
  mapsUrl: string | null;
  note: string | null;
  imageUrl: string | null;
  rating: number;
  hasReminder: boolean;
  latitude: number | null;
  longitude: number | null;
}>;

export type CategoryUpdatePayload = Partial<{
  name: string;
  icon: string;
}>;

export type ScheduleUpdatePayload = Partial<{
  placeId: string;
  date: string;
  time: string;
  status: Schedule['status'];
  hasReminder: boolean;
}>;
