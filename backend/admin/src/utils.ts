import type {
  ApiRequestLog,
  ImageAsset,
  Schedule,
  SystemEvent,
} from './types';

export type Tone = 'success' | 'warn' | 'danger' | 'muted';

export function formatTime(value?: string | null) {
  if (!value) return '-';
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

export function formatDate(value?: string | null) {
  if (!value) return '-';
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date(value));
}

export function toDateInput(value?: string | null) {
  if (!value) return '';
  return new Date(value).toISOString().slice(0, 10);
}

export function short(value?: string | null, max = 26) {
  if (!value) return '-';
  if (value.length <= max) return value;
  return `${value.slice(0, 12)}...${value.slice(-8)}`;
}

export function toneForSeverity(severity: SystemEvent['severity']): Tone {
  if (severity === 'ERROR') return 'danger';
  if (severity === 'WARN') return 'warn';
  if (severity === 'DEBUG') return 'muted';
  return 'success';
}

export function toneForSchedule(status: Schedule['status']): Tone {
  if (status === 'DONE') return 'success';
  if (status === 'CANCELLED') return 'danger';
  return 'warn';
}

export function toneForResponse(status: ApiRequestLog['responseStatus']): Tone {
  if (status === 'OK') return 'success';
  if (status === 'WARN') return 'warn';
  return 'danger';
}

export function toneForUpload(status: ImageAsset['status']): Tone {
  return status === 'SUCCESS' ? 'success' : 'danger';
}

export function nullableText(value: string) {
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

export function nullableNumber(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}

export function valueOrDash(value?: string | number | null) {
  if (value === undefined || value === null || value === '') return '-';
  return value;
}
