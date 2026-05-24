import {
  AlertTriangle,
  ExternalLink,
  Image as ImageIcon,
  RefreshCw,
} from 'lucide-react';

import type { QueryOptions } from '../api';
import type {
  AdminSession,
  AdminUser,
  ApiErrorLog,
  ApiRequestLog,
  Category,
  Health,
  ImageAsset,
  ImageHealthReport,
  ListResponse,
  Overview,
  Place,
  RetentionRunResult,
  RetentionPreview,
  Schedule,
  SystemEvent,
} from '../types';
import {
  DataTable,
  EmptyState,
  FilterBar,
  Kpi,
  Pagination,
  Panel,
  Rating,
  StatusPill,
} from '../components/ui';
import {
  formatDate,
  formatTime,
  short,
  toneForResponse,
  toneForSchedule,
  toneForSeverity,
  toneForUpload,
  valueOrDash,
} from '../utils';

export type DrawerState =
  | { kind: 'place'; item: Place }
  | { kind: 'category'; item: Category }
  | { kind: 'schedule'; item: Schedule }
  | { kind: 'user'; item: AdminUser }
  | { kind: 'activity'; item: SystemEvent }
  | { kind: 'error'; item: ApiErrorLog }
  | { kind: 'request'; item: ApiRequestLog }
  | { kind: 'upload'; item: ImageAsset };

type ListFilters = QueryOptions & {
  page: number;
  limit: number;
};

type FilterChange = (patch: Partial<ListFilters>) => void;

export function OverviewPage({
  overview,
  health,
  onOpen,
}: {
  overview: Overview | null;
  health: Health | null;
  onOpen: (drawer: DrawerState) => void;
}) {
  const kpis = overview?.kpis;
  const attentionItems = [
    ...(overview?.attention?.cloudinaryMissing
      ? ['Cloudinary chưa được cấu hình']
      : []),
    ...((overview?.attention?.latestErrors ?? []).slice(0, 3).map(
      (error) => `${error.statusCode} ${error.path}`,
    )),
    ...((overview?.attention?.slowRequests ?? []).slice(0, 3).map(
      (request) => `${request.durationMs}ms ${request.path}`,
    )),
    ...((overview?.attention?.failedUploads ?? []).slice(0, 3).map(
      (upload) => `Upload lỗi: ${upload.originalName ?? short(upload.url)}`,
    )),
  ];

  return (
    <div className="grid-flow">
      <div className="kpi-grid">
        <Kpi label="Users" value={kpis?.totalUsers ?? 0} />
        <Kpi label="Địa điểm" value={kpis?.totalPlaces ?? 0} />
        <Kpi label="Lỗi hôm nay" value={kpis?.errorsToday ?? 0} tone="danger" />
        <Kpi
          label="Phản hồi TB"
          value={`${kpis?.averageResponseMs ?? 0} ms`}
        />
        <Kpi
          label="Upload ảnh"
          value={`${kpis?.uploadSuccessRate ?? 100}%`}
          tone="success"
        />
        <Kpi label="Thiết bị hoạt động" value={kpis?.activeDevices ?? 0} />
      </div>
      <div className="dashboard-grid">
        <HealthPage health={health} compact />
        <Panel
          title="Cần chú ý"
          subtitle={`${attentionItems.length} mục`}
          compact
        >
          {attentionItems.length === 0 ? (
            <EmptyState text="Chưa có cảnh báo cần xử lý." />
          ) : (
            <div className="attention-list">
              {attentionItems.map((item) => (
                <div key={item} className="attention-item">
                  <AlertTriangle size={16} />
                  <span>{item}</span>
                </div>
              ))}
            </div>
          )}
        </Panel>
        <Panel title="Hoạt động mới" subtitle="12 event gần nhất" compact>
          <DataTable
            empty="Chưa có hoạt động được ghi nhận."
            headers={['Loại', 'Hành động', 'Mức', 'Thời gian']}
            rows={(overview?.latestActivity ?? []).map((event) => ({
              key: event.id,
              onClick: () => onOpen({ kind: 'activity', item: event }),
              cells: [
                <strong>{event.type}</strong>,
                event.action ?? '-',
                <StatusPill
                  tone={toneForSeverity(event.severity)}
                  label={event.severity}
                />,
                formatTime(event.createdAt),
              ],
            }))}
          />
        </Panel>
        <Panel title="Địa điểm mới" subtitle="8 bản ghi gần nhất" compact>
          <DataTable
            empty="Chưa có địa điểm."
            headers={['Tên', 'Danh mục', 'Rating', 'Ảnh']}
            rows={(overview?.latestPlaces ?? []).map((place) => ({
              key: place.id,
              onClick: () => onOpen({ kind: 'place', item: place }),
              cells: [
                <strong>{place.name}</strong>,
                place.category?.name ?? '-',
                <Rating value={place.rating} />,
                place.imageUrl ? 'Có ảnh' : 'Thiếu ảnh',
              ],
            }))}
          />
        </Panel>
      </div>
    </div>
  );
}

export function PlacesPage({
  data,
  filters,
  categories,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<Place>;
  filters: ListFilters;
  categories: Category[];
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Địa điểm" subtitle={`${data.total} bản ghi`}>
      <FilterBar>
        <select
          value={filters.categoryId ?? ''}
          onChange={(event) =>
            onFilterChange({ categoryId: event.target.value, page: 1 })
          }
        >
          <option value="">Tất cả danh mục</option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.name}
            </option>
          ))}
        </select>
        <select
          value={filters.imageStatus ?? ''}
          onChange={(event) =>
            onFilterChange({ imageStatus: event.target.value, page: 1 })
          }
        >
          <option value="">Tất cả ảnh</option>
          <option value="with-image">Có ảnh</option>
          <option value="without-image">Thiếu ảnh</option>
        </select>
        <select
          value={filters.minRating ?? ''}
          onChange={(event) =>
            onFilterChange({ minRating: event.target.value, page: 1 })
          }
        >
          <option value="">Mọi rating</option>
          <option value="4">Từ 4.0</option>
          <option value="4.5">Từ 4.5</option>
        </select>
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chưa có địa điểm phù hợp."
        headers={['Tên', 'Danh mục', 'Rating', 'Ảnh', 'Cập nhật']}
        rows={data.items.map((place) => ({
          key: place.id,
          onClick: () => onOpen({ kind: 'place', item: place }),
          cells: [
            <strong>{place.name}</strong>,
            place.category?.name ?? '-',
            <Rating value={place.rating} />,
            <StatusPill
              tone={place.imageUrl ? 'success' : 'muted'}
              label={place.imageUrl ? 'Có ảnh' : 'Thiếu ảnh'}
            />,
            formatTime(place.createdAt),
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function CategoriesPage({
  data,
  filters,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<Category>;
  filters: ListFilters;
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Danh mục" subtitle={`${data.total} danh mục`}>
      <FilterBar>
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chưa có danh mục phù hợp."
        headers={['Icon', 'Tên', 'Số địa điểm', 'Ngày tạo']}
        rows={data.items.map((category) => ({
          key: category.id,
          onClick: () => onOpen({ kind: 'category', item: category }),
          cells: [
            category.icon,
            <strong>{category.name}</strong>,
            category._count?.places ?? 0,
            formatTime(category.createdAt),
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function SchedulesPage({
  data,
  filters,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<Schedule>;
  filters: ListFilters;
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Lịch trình" subtitle={`${data.total} lịch`}>
      <FilterBar>
        <select
          value={filters.status ?? ''}
          onChange={(event) =>
            onFilterChange({ status: event.target.value, page: 1 })
          }
        >
          <option value="">Tất cả trạng thái</option>
          <option value="UPCOMING">UPCOMING</option>
          <option value="DONE">DONE</option>
          <option value="CANCELLED">CANCELLED</option>
        </select>
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chưa có lịch trình phù hợp."
        headers={['Địa điểm', 'Ngày', 'Giờ', 'Trạng thái', 'Nhắc nhở']}
        rows={data.items.map((schedule) => ({
          key: schedule.id,
          onClick: () => onOpen({ kind: 'schedule', item: schedule }),
          cells: [
            <strong>{schedule.place?.name ?? '-'}</strong>,
            formatDate(schedule.date),
            schedule.time,
            <StatusPill
              tone={toneForSchedule(schedule.status)}
              label={schedule.status}
            />,
            schedule.hasReminder ? 'Có' : 'Không',
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function ActivityPage({
  data,
  filters,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<SystemEvent>;
  filters: ListFilters;
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Hoạt động" subtitle={`${data.total} event`}>
      <FilterBar>
        <input
          value={filters.type ?? ''}
          onChange={(event) =>
            onFilterChange({ type: event.target.value, page: 1 })
          }
          placeholder="Loại event"
        />
        <select
          value={filters.severity ?? ''}
          onChange={(event) =>
            onFilterChange({ severity: event.target.value, page: 1 })
          }
        >
          <option value="">Mọi mức</option>
          <option value="INFO">INFO</option>
          <option value="WARN">WARN</option>
          <option value="ERROR">ERROR</option>
          <option value="DEBUG">DEBUG</option>
        </select>
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chưa có hoạt động được ghi nhận."
        headers={['Loại', 'Hành động', 'Thiết bị', 'Mức', 'Thời gian']}
        rows={data.items.map((event) => ({
          key: event.id,
          onClick: () => onOpen({ kind: 'activity', item: event }),
          cells: [
            <strong>{event.type}</strong>,
            event.action ?? '-',
            short(event.deviceId),
            <StatusPill
              tone={toneForSeverity(event.severity)}
              label={event.severity}
            />,
            formatTime(event.createdAt),
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function ErrorsPage({
  data,
  filters,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<ApiErrorLog>;
  filters: ListFilters;
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Lỗi API" subtitle={`${data.total} lỗi`}>
      <FilterBar>
        <input
          value={filters.status ?? ''}
          onChange={(event) =>
            onFilterChange({ status: event.target.value, page: 1 })
          }
          placeholder="Mã status, ví dụ 500"
        />
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chưa có lỗi API trong bộ lọc hiện tại."
        headers={['Endpoint', 'Status', 'Message', 'Thiết bị', 'Thời gian']}
        rows={data.items.map((error) => ({
          key: error.id,
          onClick: () => onOpen({ kind: 'error', item: error }),
          cells: [
            <code>{error.method} {error.path}</code>,
            <StatusPill tone="danger" label={`${error.statusCode}`} />,
            error.message,
            short(error.deviceId),
            formatTime(error.createdAt),
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function RequestsPage({
  data,
  filters,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<ApiRequestLog>;
  filters: ListFilters;
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Request API" subtitle={`${data.total} request`}>
      <FilterBar>
        <select
          value={filters.status ?? ''}
          onChange={(event) =>
            onFilterChange({ status: event.target.value, page: 1 })
          }
        >
          <option value="">Tất cả response</option>
          <option value="OK">OK</option>
          <option value="WARN">WARN</option>
          <option value="ERROR">ERROR</option>
        </select>
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chưa có request phù hợp."
        headers={['Endpoint', 'Status', 'Duration', 'Thiết bị', 'Thời gian']}
        rows={data.items.map((request) => ({
          key: request.id,
          onClick: () => onOpen({ kind: 'request', item: request }),
          cells: [
            <code>{request.method} {request.path}</code>,
            <StatusPill
              tone={toneForResponse(request.responseStatus)}
              label={`${request.statusCode}`}
            />,
            `${request.durationMs} ms`,
            short(request.deviceId),
            formatTime(request.createdAt),
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function UploadsPage({
  data,
  filters,
  imageHealthReport,
  isCheckingImages,
  onCheckImages,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<ImageAsset>;
  filters: ListFilters;
  imageHealthReport: ImageHealthReport | null;
  isCheckingImages: boolean;
  onCheckImages: () => void;
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  const unhealthyImages =
    imageHealthReport?.items.filter((item) => item.status !== 'OK') ?? [];

  return (
    <Panel
      title="Upload ảnh"
      subtitle={`${data.total} ảnh`}
      actions={
        <button
          className="secondary-button"
          disabled={isCheckingImages}
          onClick={onCheckImages}
          type="button"
        >
          <RefreshCw size={16} />
          {isCheckingImages ? 'Đang kiểm tra' : 'Kiểm tra ảnh'}
        </button>
      }
    >
      {imageHealthReport && (
        <div className="maintenance-block">
          <div className="settings-grid">
            <Setting label="Đã kiểm tra" value={`${imageHealthReport.total}`} />
            <Setting label="Ảnh OK" value={`${imageHealthReport.ok}`} />
            <Setting label="Ảnh hỏng" value={`${imageHealthReport.broken}`} />
            <Setting label="Thiếu ảnh" value={`${imageHealthReport.missing}`} />
          </div>
          <DataTable
            empty="Không có ảnh hỏng hoặc thiếu trong lần kiểm tra này."
            headers={['Địa điểm', 'Trạng thái', 'HTTP', 'Lỗi']}
            rows={unhealthyImages.map((item) => ({
              key: item.placeId,
              cells: [
                <strong>{item.name}</strong>,
                <StatusPill
                  tone={item.status === 'BROKEN' ? 'danger' : 'warn'}
                  label={item.status}
                />,
                item.statusCode ?? '-',
                item.errorMessage ?? '-',
              ],
            }))}
          />
        </div>
      )}
      <FilterBar>
        <select
          value={filters.imageStatus ?? ''}
          onChange={(event) =>
            onFilterChange({ imageStatus: event.target.value, page: 1 })
          }
        >
          <option value="">Tất cả status</option>
          <option value="SUCCESS">SUCCESS</option>
          <option value="FAILED">FAILED</option>
        </select>
        <select
          value={filters.type ?? ''}
          onChange={(event) =>
            onFilterChange({ type: event.target.value, page: 1 })
          }
        >
          <option value="">Tất cả storage</option>
          <option value="CLOUDINARY">CLOUDINARY</option>
          <option value="LOCAL">LOCAL</option>
          <option value="UNCONFIGURED">UNCONFIGURED</option>
        </select>
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chưa có upload ảnh phù hợp."
        headers={['File', 'Storage', 'Status', 'Dung lượng', 'Thời gian']}
        rows={data.items.map((upload) => ({
          key: upload.id,
          onClick: () => onOpen({ kind: 'upload', item: upload }),
          cells: [
            <span className="with-icon">
              <ImageIcon size={16} />
              {upload.originalName ?? short(upload.url)}
            </span>,
            upload.storage,
            <StatusPill
              tone={toneForUpload(upload.status)}
              label={upload.status}
            />,
            upload.sizeBytes ? `${Math.round(upload.sizeBytes / 1024)} KB` : '-',
            formatTime(upload.createdAt),
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function UsersPage({
  data,
  filters,
  onFilterChange,
  onOpen,
}: {
  data: ListResponse<AdminUser>;
  filters: ListFilters;
  onFilterChange: FilterChange;
  onOpen: (drawer: DrawerState) => void;
}) {
  return (
    <Panel title="Users" subtitle={`${data.total} user`}>
      <FilterBar>
        <DateRangeFilters filters={filters} onFilterChange={onFilterChange} />
      </FilterBar>
      <DataTable
        empty="Chua co user phu hop."
        headers={[
          'Email',
          'Ten',
          'Provider',
          'Email',
          'Du lieu',
          'Lan dang nhap gan nhat',
        ]}
        rows={data.items.map((user) => ({
          key: user.id,
          onClick: () => onOpen({ kind: 'user', item: user }),
          cells: [
            <strong>{user.email}</strong>,
            user.name,
            user.accounts.map((account) => account.provider).join(', ') || '-',
            user.emailVerifiedAt ? 'Verified' : 'Unverified',
            `${user._count.places} places / ${user._count.schedules} schedules`,
            user.lastLoginAt ? formatTime(user.lastLoginAt) : '-',
          ],
        }))}
      />
      <Pagination data={data} onPageChange={(page) => onFilterChange({ page })} />
    </Panel>
  );
}

export function HealthPage({
  health,
  compact,
}: {
  health: Health | null;
  compact?: boolean;
}) {
  return (
    <Panel
      title="Sức khỏe hệ thống"
      subtitle={health?.backend.environment ?? 'Đang tải'}
      compact={compact}
    >
      <div className="health-grid">
        <HealthItem label="Backend" value={health?.backend.status ?? '-'} tone="success" />
        <HealthItem
          label="Database"
          value={`${health?.database.status ?? '-'} · ${health?.database.latencyMs ?? 0} ms`}
          tone="success"
        />
        <HealthItem
          label="Cloudinary"
          value={health?.cloudinary.status ?? '-'}
          tone={health?.cloudinary.status === 'configured' ? 'success' : 'warn'}
        />
        <HealthItem
          label="Uptime"
          value={`${health?.backend.uptimeSeconds ?? 0}s`}
          tone="muted"
        />
      </div>
    </Panel>
  );
}

export function SettingsPage({
  session,
  health,
  autoRefreshEnabled,
  retentionPreview,
  retentionResult,
  retentionRunning,
  onToggleAutoRefresh,
  onRefresh,
  onRunRetention,
}: {
  session: AdminSession;
  health: Health | null;
  autoRefreshEnabled: boolean;
  retentionPreview: RetentionPreview | null;
  retentionResult: RetentionRunResult | null;
  retentionRunning: boolean;
  onToggleAutoRefresh: (value: boolean) => void;
  onRefresh: () => void;
  onRunRetention: () => void;
}) {
  return (
    <Panel title="Cài đặt" subtitle="Phiên admin và cấu hình kết nối">
      <div className="settings-grid">
        <Setting label="Admin" value={session.admin.email} />
        <Setting label="API base" value={import.meta.env.VITE_API_BASE_URL || '/api/v1'} />
        <Setting label="Render URL" value={health?.admin.renderUrl ?? '-'} />
        <Setting label="Cloudinary" value={health?.cloudinary.status ?? '-'} />
      </div>
      <label className="toggle-line">
        <input
          checked={autoRefreshEnabled}
          onChange={(event) => onToggleAutoRefresh(event.target.checked)}
          type="checkbox"
        />
        Auto-refresh mỗi 10 giây
      </label>
      <button className="primary-button compact" onClick={onRefresh} type="button">
        <RefreshCw size={17} />
        Tải lại dữ liệu
      </button>
      <div className="maintenance-block">
        <div className="panel-head inline-head">
          <div>
            <h2>Retention log</h2>
            <span>Dọn dữ liệu vận hành cũ theo chính sách an toàn.</span>
          </div>
          <button
            className="secondary-button"
            disabled={retentionRunning}
            onClick={onRunRetention}
            type="button"
          >
            <RefreshCw size={16} />
            {retentionRunning ? 'Đang dọn' : 'Chạy dọn log'}
          </button>
        </div>
        <div className="settings-grid">
          <Setting
            label={`Request log > ${retentionPreview?.policy.requestLogDays ?? 30} ngày`}
            value={`${retentionPreview?.counts.apiRequestLogs ?? 0}`}
          />
          <Setting
            label={`Error log > ${retentionPreview?.policy.errorLogDays ?? 90} ngày`}
            value={`${retentionPreview?.counts.apiErrorLogs ?? 0}`}
          />
          <Setting
            label={`Activity > ${retentionPreview?.policy.systemEventDays ?? 90} ngày`}
            value={`${retentionPreview?.counts.systemEvents ?? 0}`}
          />
          <Setting
            label={`Image asset > ${retentionPreview?.policy.imageAssetDays ?? 180} ngày`}
            value={`${retentionPreview?.counts.imageAssets ?? 0}`}
          />
        </div>
        {retentionResult && (
          <div className="attention-item success-note">
            Đã dọn {sumRetention(retentionResult.deleted)} bản ghi cũ.
          </div>
        )}
      </div>
    </Panel>
  );
}

function DateRangeFilters({
  filters,
  onFilterChange,
}: {
  filters: ListFilters;
  onFilterChange: FilterChange;
}) {
  return (
    <>
      <input
        type="date"
        value={filters.from ?? ''}
        onChange={(event) => onFilterChange({ from: event.target.value, page: 1 })}
      />
      <input
        type="date"
        value={filters.to ?? ''}
        onChange={(event) => onFilterChange({ to: event.target.value, page: 1 })}
      />
    </>
  );
}

function HealthItem({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: 'success' | 'warn' | 'danger' | 'muted';
}) {
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
      <strong>{valueOrDash(value)}</strong>
    </div>
  );
}

function sumRetention(counts: RetentionRunResult['deleted']) {
  return (
    counts.apiRequestLogs +
    counts.apiErrorLogs +
    counts.systemEvents +
    counts.imageAssets
  );
}

export function externalLink(url?: string | null) {
  if (!url) return '-';
  return (
    <a href={url} rel="noreferrer" target="_blank">
      Mở <ExternalLink size={13} />
    </a>
  );
}
