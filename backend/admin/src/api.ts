import type {
  AdminSession,
  ApiEnvelope,
  ApiErrorLog,
  ApiRequestLog,
  Category,
  CategoryUpdatePayload,
  Health,
  ImageAsset,
  ImageHealthReport,
  ListResponse,
  Overview,
  Place,
  PlaceUpdatePayload,
  RetentionPreview,
  RetentionRunResult,
  Schedule,
  ScheduleUpdatePayload,
  SystemEvent,
} from './types';

const baseUrl = import.meta.env.VITE_API_BASE_URL || '/api/v1';

export class AuthExpiredError extends Error {
  constructor() {
    super('Phiên đăng nhập đã hết hạn');
  }
}

export class AdminApi {
  constructor(private readonly token: string | null) {}

  login(email: string, password: string) {
    return this.request<AdminSession>('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
  }

  overview() {
    return this.request<Overview>('/admin/overview');
  }

  health() {
    return this.request<Health>('/admin/health');
  }

  places(query: QueryOptions) {
    return this.request<ListResponse<Place>>(`/admin/places${toSearch(query)}`);
  }

  categories(query: QueryOptions) {
    return this.request<ListResponse<Category>>(
      `/admin/categories${toSearch(query)}`,
    );
  }

  schedules(query: QueryOptions) {
    return this.request<ListResponse<Schedule>>(
      `/admin/schedules${toSearch(query)}`,
    );
  }

  activity(query: QueryOptions) {
    return this.request<ListResponse<SystemEvent>>(
      `/admin/activity${toSearch(query)}`,
    );
  }

  errors(query: QueryOptions) {
    return this.request<ListResponse<ApiErrorLog>>(
      `/admin/errors${toSearch(query)}`,
    );
  }

  requests(query: QueryOptions) {
    return this.request<ListResponse<ApiRequestLog>>(
      `/admin/requests${toSearch(query)}`,
    );
  }

  uploads(query: QueryOptions) {
    return this.request<ListResponse<ImageAsset>>(
      `/admin/uploads${toSearch(query)}`,
    );
  }

  checkImages(query: Pick<QueryOptions, 'limit' | 'q'> = {}) {
    return this.request<ImageHealthReport>(
      `/admin/images/check${toSearch(query)}`,
      { method: 'POST' },
    );
  }

  retentionPreview() {
    return this.request<RetentionPreview>(
      '/admin/maintenance/retention/preview',
    );
  }

  runRetention() {
    return this.request<RetentionRunResult>(
      '/admin/maintenance/retention/run',
      { method: 'POST' },
    );
  }

  updatePlace(id: string, payload: PlaceUpdatePayload) {
    return this.request<Place>(`/admin/places/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  deletePlace(id: string) {
    return this.request<{ id: string }>(`/admin/places/${id}`, {
      method: 'DELETE',
    });
  }

  updateCategory(id: string, payload: CategoryUpdatePayload) {
    return this.request<Category>(`/admin/categories/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  deleteCategory(id: string) {
    return this.request<{ id: string }>(`/admin/categories/${id}`, {
      method: 'DELETE',
    });
  }

  updateSchedule(id: string, payload: ScheduleUpdatePayload) {
    return this.request<Schedule>(`/admin/schedules/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  deleteSchedule(id: string) {
    return this.request<{ id: string }>(`/admin/schedules/${id}`, {
      method: 'DELETE',
    });
  }

  private async request<T>(path: string, init: RequestInit = {}) {
    const response = await fetch(`${baseUrl}${path}`, {
      ...init,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
        ...init.headers,
      },
    });

    const text = await response.text();
    let envelope: ApiEnvelope<T>;
    try {
      envelope = JSON.parse(text) as ApiEnvelope<T>;
    } catch {
      throw new Error('Backend chưa trả về dữ liệu JSON hợp lệ');
    }

    if (!response.ok) {
      if (response.status === 401 && this.token) {
        throw new AuthExpiredError();
      }
      throw new Error(envelope.message || 'Request failed');
    }

    return envelope.data;
  }
}

export type QueryOptions = {
  q?: string;
  page?: number;
  limit?: number;
  status?: string;
  type?: string;
  severity?: string;
  categoryId?: string;
  imageStatus?: string;
  minRating?: string | number;
  from?: string;
  to?: string;
};

function toSearch(query: QueryOptions) {
  const params = new URLSearchParams();
  Object.entries(query).forEach(([key, value]) => {
    if (value !== undefined && value !== null && `${value}`.trim() !== '') {
      params.set(key, `${value}`);
    }
  });
  const search = params.toString();
  return search ? `?${search}` : '';
}
