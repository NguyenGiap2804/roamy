import type {
  AdminSession,
  ApiErrorLog,
  ApiRequestLog,
  Category,
  Health,
  ImageAsset,
  ListResponse,
  Overview,
  Place,
  Schedule,
  SystemEvent,
  ApiEnvelope,
} from './types';

const baseUrl = import.meta.env.VITE_API_BASE_URL || '/api/v1';

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
    return this.request<ListResponse<Category>>(`/admin/categories${toSearch(query)}`);
  }

  schedules(query: QueryOptions) {
    return this.request<ListResponse<Schedule>>(`/admin/schedules${toSearch(query)}`);
  }

  activity(query: QueryOptions) {
    return this.request<ListResponse<SystemEvent>>(`/admin/activity${toSearch(query)}`);
  }

  errors(query: QueryOptions) {
    return this.request<ListResponse<ApiErrorLog>>(`/admin/errors${toSearch(query)}`);
  }

  requests(query: QueryOptions) {
    return this.request<ListResponse<ApiRequestLog>>(`/admin/requests${toSearch(query)}`);
  }

  uploads(query: QueryOptions) {
    return this.request<ListResponse<ImageAsset>>(`/admin/uploads${toSearch(query)}`);
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
