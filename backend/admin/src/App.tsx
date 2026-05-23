import {
  Activity,
  AlertTriangle,
  CalendarDays,
  Database,
  FolderTree,
  Gauge,
  HeartPulse,
  Image,
  LogOut,
  MapPin,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  UploadCloud,
  UserRound,
} from 'lucide-react';
import { FormEvent, ReactNode, useCallback, useEffect, useMemo, useState } from 'react';

import { AdminApi } from './api';
import type {
  AdminSession,
  ApiErrorLog,
  ApiRequestLog,
  Category,
  Health,
  ImageAsset,
  Overview,
  Place,
  Schedule,
  SystemEvent,
} from './types';

type Section =
  | 'overview'
  | 'places'
  | 'categories'
  | 'schedules'
  | 'activity'
  | 'errors'
  | 'requests'
  | 'uploads'
  | 'health'
  | 'settings';

type DateRange = '24h' | '7d' | 'all';

type DashboardState = {
  overview: Overview | null;
  health: Health | null;
  places: Place[];
  categories: Category[];
  schedules: Schedule[];
  activity: SystemEvent[];
  errors: ApiErrorLog[];
  requests: ApiRequestLog[];
  uploads: ImageAsset[];
};

type DrawerState = {
  title: string;
  subtitle?: string;
  item: unknown;
};

const emptyState: DashboardState = {
  overview: null,
  health: null,
  places: [],
  categories: [],
  schedules: [],
  activity: [],
  errors: [],
  requests: [],
  uploads: [],
};

const navItems: Array<{ id: Section; label: string; icon: ReactNode }> = [
  { id: 'overview', label: 'Tổng quan', icon: <Gauge size={18} /> },
  { id: 'places', label: 'Địa điểm', icon: <MapPin size={18} /> },
  { id: 'categories', label: 'Danh mục', icon: <FolderTree size={18} /> },
  { id: 'schedules', label: 'Lịch trình', icon: <CalendarDays size={18} /> },
  { id: 'activity', label: 'Hoạt động', icon: <Activity size={18} /> },
  { id: 'errors', label: 'Lỗi API', icon: <AlertTriangle size={18} /> },
  { id: 'requests', label: 'Request API', icon: <Database size={18} /> },
  { id: 'uploads', label: 'Upload ảnh', icon: <UploadCloud size={18} /> },
  { id: 'health', label: 'Sức khỏe hệ thống', icon: <HeartPulse size={18} /> },
  { id: 'settings', label: 'Cài đặt', icon: <Settings size={18} /> },
];

export function App() {
  const [session, setSession] = useState<AdminSession | null>(() => {
    const raw = localStorage.getItem('roamy-admin-session');
    return raw ? (JSON.parse(raw) as AdminSession) : null;
  });
  const [active, setActive] = useState<Section>('overview');
  const [state, setState] = useState<DashboardState>(emptyState);
  const [query, setQuery] = useState('');
  const [range, setRange] = useState<DateRange>('24h');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [drawer, setDrawer] = useState<DrawerState | null>(null);

  const api = useMemo(() => new AdminApi(session?.token ?? null), [session]);

  const load = useCallback(async () => {
    if (!session) return;

    setLoading(true);
    setError(null);
    try {
      const listQuery = { q: query, limit: 80 };
      const [
        overview,
        health,
        places,
        categories,
        schedules,
        activity,
        errors,
        requests,
        uploads,
      ] = await Promise.all([
        api.overview(),
        api.health(),
        api.places(listQuery),
        api.categories(listQuery),
        api.schedules(listQuery),
        api.activity(listQuery),
        api.errors(listQuery),
        api.requests(listQuery),
        api.uploads(listQuery),
      ]);

      setState({
        overview,
        health,
        places: places.items,
        categories: categories.items,
        schedules: schedules.items,
        activity: activity.items,
        errors: errors.items,
        requests: requests.items,
        uploads: uploads.items,
      });
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Không tải được dữ liệu');
    } finally {
      setLoading(false);
    }
  }, [api, query, session]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!session) {
    return (
      <LoginScreen
        api={api}
        onLogin={(nextSession) => {
          localStorage.setItem('roamy-admin-session', JSON.stringify(nextSession));
          setSession(nextSession);
        }}
      />
    );
  }

  const ranged = applyDateRange(state, range);

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">R</div>
          <div>
            <strong>Roamy Admin</strong>
            <span>System console</span>
          </div>
        </div>
        <nav className="nav-list">
          {navItems.map((item) => (
            <button
              key={item.id}
              className={active === item.id ? 'nav-item active' : 'nav-item'}
              onClick={() => setActive(item.id)}
              type="button"
            >
              {item.icon}
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        <button
          className="logout"
          onClick={() => {
            localStorage.removeItem('roamy-admin-session');
            setSession(null);
          }}
          type="button"
        >
          <LogOut size={17} />
          Đăng xuất
        </button>
      </aside>

      <main className="main">
        <header className="topbar">
          <div className="search-box">
            <Search size={18} />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Tìm địa điểm, thiết bị, endpoint, lỗi..."
            />
          </div>
          <select value={range} onChange={(event) => setRange(event.target.value as DateRange)}>
            <option value="24h">24 giờ</option>
            <option value="7d">7 ngày</option>
            <option value="all">Tất cả</option>
          </select>
          <button className="icon-button" onClick={() => void load()} type="button">
            <RefreshCw size={18} />
          </button>
          <span className="env-badge">{state.health?.backend.environment ?? 'Local'}</span>
          <div className="avatar">
            <UserRound size={17} />
            <span>{session.admin.email}</span>
          </div>
        </header>

        {error && <div className="error-banner">{error}</div>}
        {loading && <div className="loading-bar" />}

        <section className="content">
          {active === 'overview' && (
            <OverviewPanel
              state={ranged}
              onOpen={setDrawer}
            />
          )}
          {active === 'places' && (
            <PlacesPanel places={ranged.places} onOpen={setDrawer} />
          )}
          {active === 'categories' && (
            <CategoriesPanel categories={ranged.categories} onOpen={setDrawer} />
          )}
          {active === 'schedules' && (
            <SchedulesPanel schedules={ranged.schedules} onOpen={setDrawer} />
          )}
          {active === 'activity' && (
            <ActivityPanel events={ranged.activity} onOpen={setDrawer} />
          )}
          {active === 'errors' && (
            <ErrorsPanel errors={ranged.errors} onOpen={setDrawer} />
          )}
          {active === 'requests' && (
            <RequestsPanel requests={ranged.requests} onOpen={setDrawer} />
          )}
          {active === 'uploads' && (
            <UploadsPanel uploads={ranged.uploads} onOpen={setDrawer} />
          )}
          {active === 'health' && <HealthPanel health={state.health} />}
          {active === 'settings' && (
            <SettingsPanel
              session={session}
              health={state.health}
              onRefresh={() => void load()}
            />
          )}
        </section>
      </main>

      {drawer && (
        <DetailDrawer drawer={drawer} onClose={() => setDrawer(null)} />
      )}
    </div>
  );
}

function LoginScreen({
  api,
  onLogin,
}: {
  api: AdminApi;
  onLogin: (session: AdminSession) => void;
}) {
  const [email, setEmail] = useState('admin@roamy.local');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    try {
      onLogin(await api.login(email, password));
    } catch (loginError) {
      setError(loginError instanceof Error ? loginError.message : 'Đăng nhập thất bại');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <form className="login-card" onSubmit={submit}>
        <div className="brand-mark large">R</div>
        <h1>Roamy Admin</h1>
        <p>Đăng nhập để xem dữ liệu, lỗi phản hồi và hoạt động hệ thống.</p>
        <label>
          Email admin
          <input value={email} onChange={(event) => setEmail(event.target.value)} />
        </label>
        <label>
          Mật khẩu
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="ADMIN_PASSWORD"
          />
        </label>
        {error && <div className="form-error">{error}</div>}
        <button className="primary-button" disabled={loading} type="submit">
          <ShieldCheck size={18} />
          {loading ? 'Đang kiểm tra...' : 'Đăng nhập'}
        </button>
      </form>
    </main>
  );
}

function OverviewPanel({
  state,
  onOpen,
}: {
  state: DashboardState;
  onOpen: (drawer: DrawerState) => void;
}) {
  const kpis = state.overview?.kpis;
  return (
    <div className="grid-flow">
      <div className="kpi-grid">
        <Kpi label="Địa điểm" value={kpis?.totalPlaces ?? state.places.length} />
        <Kpi label="Lỗi hôm nay" value={kpis?.errorsToday ?? state.errors.length} tone="danger" />
        <Kpi label="Phản hồi TB" value={`${kpis?.averageResponseMs ?? averageResponse(state.requests)} ms`} />
        <Kpi label="Upload ảnh" value={`${kpis?.uploadSuccessRate ?? uploadRate(state.uploads)}%`} tone="success" />
        <Kpi label="Thiết bị hoạt động" value={kpis?.activeDevices ?? uniqueDevices(state.activity)} />
      </div>
      <div className="dashboard-grid">
        <HealthPanel health={state.health} compact />
        <ActivityPanel events={state.activity.slice(0, 8)} onOpen={onOpen} compact />
        <ErrorsPanel errors={state.errors.slice(0, 6)} onOpen={onOpen} compact />
        <PlacesPanel places={state.places.slice(0, 8)} onOpen={onOpen} compact />
      </div>
    </div>
  );
}

function PlacesPanel({
  places,
  onOpen,
  compact,
}: {
  places: Place[];
  onOpen: (drawer: DrawerState) => void;
  compact?: boolean;
}) {
  return (
    <Panel title="Địa điểm" subtitle={`${places.length} bản ghi`} compact={compact}>
      <Table
        empty="Chưa có địa điểm phù hợp."
        headers={['Tên', 'Danh mục', 'Rating', 'Ảnh', 'Cập nhật']}
        rows={places.map((place) => ({
          key: place.id,
          onClick: () => onOpen({ title: place.name, subtitle: place.address, item: place }),
          cells: [
            <strong>{place.name}</strong>,
            place.category?.name ?? '-',
            <Rating value={place.rating} />,
            <StatusPill tone={place.imageUrl ? 'success' : 'muted'} label={place.imageUrl ? 'Có ảnh' : 'Thiếu ảnh'} />,
            formatTime(place.createdAt),
          ],
        }))}
      />
    </Panel>
  );
}

function CategoriesPanel({
  categories,
  onOpen,
}: {
  categories: Category[];
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Danh mục" subtitle={`${categories.length} danh mục`}>
      <Table
        empty="Chưa có danh mục phù hợp."
        headers={['Icon', 'Tên', 'Số địa điểm', 'Ngày tạo']}
        rows={categories.map((category) => ({
          key: category.id,
          onClick: () => onOpen({ title: category.name, item: category }),
          cells: [category.icon, <strong>{category.name}</strong>, category._count?.places ?? 0, formatTime(category.createdAt)],
        }))}
      />
    </Panel>
  );
}

function SchedulesPanel({
  schedules,
  onOpen,
}: {
  schedules: Schedule[];
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Lịch trình" subtitle={`${schedules.length} lịch`}>
      <Table
        empty="Chưa có lịch trình phù hợp."
        headers={['Địa điểm', 'Ngày', 'Giờ', 'Trạng thái', 'Nhắc nhở']}
        rows={schedules.map((schedule) => ({
          key: schedule.id,
          onClick: () => onOpen({ title: schedule.place?.name ?? schedule.id, item: schedule }),
          cells: [
            <strong>{schedule.place?.name ?? '-'}</strong>,
            formatDate(schedule.date),
            schedule.time,
            <StatusPill tone={schedule.status === 'DONE' ? 'success' : schedule.status === 'CANCELLED' ? 'danger' : 'warn'} label={schedule.status} />,
            schedule.hasReminder ? 'Có' : 'Không',
          ],
        }))}
      />
    </Panel>
  );
}

function ActivityPanel({
  events,
  onOpen,
  compact,
}: {
  events: SystemEvent[];
  onOpen: (drawer: DrawerState) => void;
  compact?: boolean;
}) {
  return (
    <Panel title="Hoạt động" subtitle={`${events.length} event`} compact={compact}>
      <Table
        empty="Chưa có hoạt động được ghi nhận."
        headers={['Loại', 'Hành động', 'Thiết bị', 'Mức', 'Thời gian']}
        rows={events.map((event) => ({
          key: event.id,
          onClick: () => onOpen({ title: `${event.type}: ${event.action ?? '-'}`, subtitle: event.deviceId ?? undefined, item: event }),
          cells: [
            <strong>{event.type}</strong>,
            event.action ?? '-',
            short(event.deviceId),
            <StatusPill tone={toneForSeverity(event.severity)} label={event.severity} />,
            formatTime(event.createdAt),
          ],
        }))}
      />
    </Panel>
  );
}

function ErrorsPanel({
  errors,
  onOpen,
  compact,
}: {
  errors: ApiErrorLog[];
  onOpen: (drawer: DrawerState) => void;
  compact?: boolean;
}) {
  return (
    <Panel title="Lỗi API" subtitle={`${errors.length} lỗi`} compact={compact}>
      <Table
        empty="Chưa có lỗi API trong bộ lọc hiện tại."
        headers={['Endpoint', 'Status', 'Message', 'Thiết bị', 'Thời gian']}
        rows={errors.map((error) => ({
          key: error.id,
          onClick: () => onOpen({ title: error.path, subtitle: error.message, item: error }),
          cells: [
            <code>{error.method} {error.path}</code>,
            <StatusPill tone="danger" label={`${error.statusCode}`} />,
            error.message,
            short(error.deviceId),
            formatTime(error.createdAt),
          ],
        }))}
      />
    </Panel>
  );
}

function RequestsPanel({
  requests,
  onOpen,
}: {
  requests: ApiRequestLog[];
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Request API" subtitle={`${requests.length} request`}>
      <Table
        empty="Chưa có request phù hợp."
        headers={['Endpoint', 'Status', 'Duration', 'Thiết bị', 'Thời gian']}
        rows={requests.map((request) => ({
          key: request.id,
          onClick: () => onOpen({ title: request.path, subtitle: request.requestId, item: request }),
          cells: [
            <code>{request.method} {request.path}</code>,
            <StatusPill tone={request.responseStatus === 'OK' ? 'success' : request.responseStatus === 'WARN' ? 'warn' : 'danger'} label={`${request.statusCode}`} />,
            `${request.durationMs} ms`,
            short(request.deviceId),
            formatTime(request.createdAt),
          ],
        }))}
      />
    </Panel>
  );
}

function UploadsPanel({
  uploads,
  onOpen,
}: {
  uploads: ImageAsset[];
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Upload ảnh" subtitle={`${uploads.length} ảnh`}>
      <Table
        empty="Chưa có upload ảnh phù hợp."
        headers={['File', 'Storage', 'Status', 'Dung lượng', 'Thời gian']}
        rows={uploads.map((upload) => ({
          key: upload.id,
          onClick: () => onOpen({ title: upload.originalName ?? upload.url, subtitle: upload.url, item: upload }),
          cells: [
            <span className="with-icon"><Image size={16} />{upload.originalName ?? short(upload.url)}</span>,
            upload.storage,
            <StatusPill tone={upload.status === 'SUCCESS' ? 'success' : 'danger'} label={upload.status} />,
            upload.sizeBytes ? `${Math.round(upload.sizeBytes / 1024)} KB` : '-',
            formatTime(upload.createdAt),
          ],
        }))}
      />
    </Panel>
  );
}

function HealthPanel({ health, compact }: { health: Health | null; compact?: boolean }) {
  return (
    <Panel title="Sức khỏe hệ thống" subtitle={health?.backend.environment ?? 'Đang tải'} compact={compact}>
      <div className="health-grid">
        <HealthItem label="Backend" value={health?.backend.status ?? '-'} tone="success" />
        <HealthItem label="Database" value={`${health?.database.status ?? '-'} · ${health?.database.latencyMs ?? 0} ms`} tone="success" />
        <HealthItem label="Cloudinary" value={health?.cloudinary.status ?? '-'} tone={health?.cloudinary.status === 'configured' ? 'success' : 'warn'} />
        <HealthItem label="Uptime" value={`${health?.backend.uptimeSeconds ?? 0}s`} tone="muted" />
      </div>
    </Panel>
  );
}

function SettingsPanel({
  session,
  health,
  onRefresh,
}: {
  session: AdminSession;
  health: Health | null;
  onRefresh: () => void;
}) {
  return (
    <Panel title="Cài đặt" subtitle="Phiên admin và cấu hình kết nối">
      <div className="settings-grid">
        <Setting label="Admin" value={session.admin.email} />
        <Setting label="API base" value={import.meta.env.VITE_API_BASE_URL || '/api/v1'} />
        <Setting label="Render URL" value={health?.admin.renderUrl ?? '-'} />
        <Setting label="Cloudinary" value={health?.cloudinary.status ?? '-'} />
      </div>
      <button className="primary-button compact" onClick={onRefresh} type="button">
        <RefreshCw size={17} />
        Tải lại dữ liệu
      </button>
    </Panel>
  );
}

function DetailDrawer({ drawer, onClose }: { drawer: DrawerState; onClose: () => void }) {
  return (
    <aside className="drawer">
      <div className="drawer-head">
        <div>
          <h2>{drawer.title}</h2>
          {drawer.subtitle && <p>{drawer.subtitle}</p>}
        </div>
        <button className="icon-button" onClick={onClose} type="button">×</button>
      </div>
      <pre>{JSON.stringify(drawer.item, null, 2)}</pre>
    </aside>
  );
}

function Panel({
  title,
  subtitle,
  children,
  compact,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  compact?: boolean;
}) {
  return (
    <section className={compact ? 'panel compact-panel' : 'panel'}>
      <div className="panel-head">
        <h2>{title}</h2>
        {subtitle && <span>{subtitle}</span>}
      </div>
      {children}
    </section>
  );
}

function Table({
  headers,
  rows,
  empty,
}: {
  headers: string[];
  rows: Array<{ key: string; cells: ReactNode[]; onClick: () => void }>;
  empty: string;
}) {
  if (rows.length === 0) {
    return <div className="empty-state">{empty}</div>;
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>{headers.map((header) => <th key={header}>{header}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.key} onClick={row.onClick}>
              {row.cells.map((cell, index) => <td key={`${row.key}-${index}`}>{cell}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Kpi({ label, value, tone }: { label: string; value: ReactNode; tone?: 'success' | 'danger' }) {
  return (
    <div className={`kpi ${tone ?? ''}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function HealthItem({ label, value, tone }: { label: string; value: string; tone: Tone }) {
  return (
    <div className="health-item">
      <StatusPill tone={tone} label={label} />
      <strong>{value}</strong>
    </div>
  );
}

function Setting({ label, value }: { label: string; value: string }) {
  return (
    <div className="setting">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

type Tone = 'success' | 'warn' | 'danger' | 'muted';

function StatusPill({ tone, label }: { tone: Tone; label: string }) {
  return <span className={`status ${tone}`}>{label}</span>;
}

function Rating({ value }: { value: number }) {
  return <span className="rating">★ {value.toFixed(1)}</span>;
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date(value));
}

function short(value?: string | null) {
  if (!value) return '-';
  return value.length > 24 ? `${value.slice(0, 10)}...${value.slice(-8)}` : value;
}

function toneForSeverity(severity: SystemEvent['severity']): Tone {
  if (severity === 'ERROR') return 'danger';
  if (severity === 'WARN') return 'warn';
  return 'success';
}

function applyDateRange(state: DashboardState, range: DateRange): DashboardState {
  if (range === 'all') return state;

  const now = Date.now();
  const windowMs = range === '24h' ? 24 * 60 * 60 * 1000 : 7 * 24 * 60 * 60 * 1000;
  const inRange = (value?: string) => !value || now - new Date(value).getTime() <= windowMs;

  return {
    ...state,
    places: state.places.filter((item) => inRange(item.createdAt)),
    categories: state.categories.filter((item) => inRange(item.createdAt)),
    schedules: state.schedules.filter((item) => inRange(item.createdAt)),
    activity: state.activity.filter((item) => inRange(item.createdAt)),
    errors: state.errors.filter((item) => inRange(item.createdAt)),
    requests: state.requests.filter((item) => inRange(item.createdAt)),
    uploads: state.uploads.filter((item) => inRange(item.createdAt)),
  };
}

function averageResponse(requests: ApiRequestLog[]) {
  if (requests.length === 0) return 0;
  return Math.round(requests.reduce((sum, item) => sum + item.durationMs, 0) / requests.length);
}

function uploadRate(uploads: ImageAsset[]) {
  if (uploads.length === 0) return 100;
  return Math.round((uploads.filter((item) => item.status === 'SUCCESS').length / uploads.length) * 100);
}

function uniqueDevices(events: SystemEvent[]) {
  return new Set(events.map((item) => item.deviceId).filter(Boolean)).size;
}
