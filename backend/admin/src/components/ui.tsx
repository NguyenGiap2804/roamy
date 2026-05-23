import type { ReactNode } from 'react';

import type { ListResponse } from '../types';
import type { Tone } from '../utils';

export function Panel({
  title,
  subtitle,
  children,
  actions,
  compact,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  actions?: ReactNode;
  compact?: boolean;
}) {
  return (
    <section className={compact ? 'panel compact-panel' : 'panel'}>
      <div className="panel-head">
        <div>
          <h2>{title}</h2>
          {subtitle && <span>{subtitle}</span>}
        </div>
        {actions && <div className="panel-actions">{actions}</div>}
      </div>
      {children}
    </section>
  );
}

export function Kpi({
  label,
  value,
  tone,
}: {
  label: string;
  value: ReactNode;
  tone?: 'success' | 'danger';
}) {
  return (
    <div className={`kpi ${tone ?? ''}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export function StatusPill({ tone, label }: { tone: Tone; label: string }) {
  return <span className={`status ${tone}`}>{label}</span>;
}

export function DataTable({
  headers,
  rows,
  empty,
}: {
  headers: string[];
  rows: Array<{ key: string; cells: ReactNode[]; onClick?: () => void }>;
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
            <tr
              key={row.key}
              className={row.onClick ? 'clickable-row' : undefined}
              onClick={row.onClick}
            >
              {row.cells.map((cell, index) => (
                <td key={`${row.key}-${index}`}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function Pagination<T>({
  data,
  onPageChange,
}: {
  data: ListResponse<T>;
  onPageChange: (page: number) => void;
}) {
  const canGoBack = data.page > 1;
  const canGoNext = data.totalPages > 0 && data.page < data.totalPages;

  return (
    <div className="pagination">
      <span>
        {data.total} bản ghi · Trang {data.totalPages === 0 ? 0 : data.page}/
        {data.totalPages}
      </span>
      <div>
        <button
          className="secondary-button"
          disabled={!canGoBack}
          onClick={() => onPageChange(data.page - 1)}
          type="button"
        >
          Trước
        </button>
        <button
          className="secondary-button"
          disabled={!canGoNext}
          onClick={() => onPageChange(data.page + 1)}
          type="button"
        >
          Sau
        </button>
      </div>
    </div>
  );
}

export function FilterBar({ children }: { children: ReactNode }) {
  return <div className="filter-bar">{children}</div>;
}

export function Field({
  label,
  value,
}: {
  label: string;
  value: ReactNode;
}) {
  return (
    <div className="detail-field">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export function FormField({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <label className="form-field">
      <span>{label}</span>
      {children}
    </label>
  );
}

export function Rating({ value }: { value: number }) {
  return <span className="rating">★ {value.toFixed(1)}</span>;
}

export function EmptyState({ text }: { text: string }) {
  return <div className="empty-state">{text}</div>;
}
