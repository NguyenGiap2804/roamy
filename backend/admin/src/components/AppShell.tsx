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
  UploadCloud,
  Users,
  UserRound,
} from 'lucide-react';
import type { ReactNode } from 'react';

import type { AdminSession, Health } from '../types';

export type Section =
  | 'overview'
  | 'places'
  | 'categories'
  | 'schedules'
  | 'activity'
  | 'errors'
  | 'requests'
  | 'uploads'
  | 'users'
  | 'health'
  | 'settings';

const navItems: Array<{ id: Section; label: string; icon: ReactNode }> = [
  { id: 'overview', label: 'Tổng quan', icon: <Gauge size={18} /> },
  { id: 'places', label: 'Địa điểm', icon: <MapPin size={18} /> },
  { id: 'categories', label: 'Danh mục', icon: <FolderTree size={18} /> },
  { id: 'schedules', label: 'Lịch trình', icon: <CalendarDays size={18} /> },
  { id: 'activity', label: 'Hoạt động', icon: <Activity size={18} /> },
  { id: 'errors', label: 'Lỗi API', icon: <AlertTriangle size={18} /> },
  { id: 'requests', label: 'Request API', icon: <Database size={18} /> },
  { id: 'uploads', label: 'Upload ảnh', icon: <UploadCloud size={18} /> },
  { id: 'users', label: 'Users', icon: <Users size={18} /> },
  { id: 'health', label: 'Sức khỏe', icon: <HeartPulse size={18} /> },
  { id: 'settings', label: 'Cài đặt', icon: <Settings size={18} /> },
];

export function AppShell({
  active,
  session,
  health,
  query,
  autoRefreshEnabled,
  lastUpdatedAt,
  onActiveChange,
  onQueryChange,
  onRefresh,
  onLogout,
  children,
}: {
  active: Section;
  session: AdminSession;
  health: Health | null;
  query: string;
  autoRefreshEnabled: boolean;
  lastUpdatedAt: Date | null;
  onActiveChange: (section: Section) => void;
  onQueryChange: (value: string) => void;
  onRefresh: () => void;
  onLogout: () => void;
  children: ReactNode;
}) {
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
              onClick={() => onActiveChange(item.id)}
              type="button"
            >
              {item.icon}
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        <button className="logout" onClick={onLogout} type="button">
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
              onChange={(event) => onQueryChange(event.target.value)}
              placeholder="Tìm địa điểm, thiết bị, endpoint, lỗi..."
            />
          </div>
          <button className="icon-button" onClick={onRefresh} type="button">
            <RefreshCw size={18} />
          </button>
          <span className="env-badge">
            {health?.backend.environment ?? 'Local'}
          </span>
          <span className={autoRefreshEnabled ? 'sync-state on' : 'sync-state'}>
            {autoRefreshEnabled ? 'Auto 10s' : 'Tạm dừng'}
          </span>
          <span className="sync-state">
            {lastUpdatedAt
              ? `Cập nhật ${lastUpdatedAt.toLocaleTimeString('vi-VN')}`
              : 'Chưa tải'}
          </span>
          <div className="avatar">
            <UserRound size={17} />
            <span>{session.admin.email}</span>
          </div>
        </header>
        {children}
      </main>
    </div>
  );
}
