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
  name: string;
  icon: string;
  createdAt: string;
  _count?: { places: number };
};

export type Place = {
  id: string;
  name: string;
  address: string;
  priceRange: string;
  openingHours: string;
  phone?: string | null;
  website?: string | null;
  mapsUrl?: string | null;
  imageUrl?: string | null;
  rating: number;
  latitude?: number | null;
  longitude?: number | null;
  createdAt: string;
  category?: Category | null;
  schedules?: Schedule[];
};

export type Schedule = {
  id: string;
  placeId: string;
  date: string;
  time: string;
  status: 'UPCOMING' | 'DONE' | 'CANCELLED';
  hasReminder: boolean;
  createdAt: string;
  place?: Place | null;
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
  requestId?: string | null;
  errorMessage?: string | null;
  createdAt: string;
};

export type ListResponse<T> = {
  total: number;
  items: T[];
};

export type Overview = {
  kpis: {
    totalPlaces: number;
    totalCategories: number;
    totalSchedules: number;
    errorsToday: number;
    averageResponseMs: number;
    uploadSuccessRate: number;
    activeDevices: number;
  };
  latestActivity: SystemEvent[];
  latestErrors: ApiErrorLog[];
  latestPlaces: Place[];
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
