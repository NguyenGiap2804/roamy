import { FormEvent, useEffect, useState } from "react";
import { X } from "lucide-react";

import type { DrawerState } from "../pages/DashboardPages";
import type {
  AdminUser,
  Category,
  CategoryUpdatePayload,
  Place,
  PlaceUpdatePayload,
  Schedule,
  ScheduleUpdatePayload,
} from "../types";
import { Field, FormField, Rating, StatusPill } from "./ui";
import {
  formatDate,
  formatTime,
  nullableNumber,
  nullableText,
  short,
  toDateInput,
  toneForResponse,
  toneForSchedule,
  toneForSeverity,
  toneForUpload,
  valueOrDash,
} from "../utils";

export function DetailDrawer({
  drawer,
  categories,
  places,
  onClose,
  onDeleteUser,
  onFocusUser,
  onUpdate,
  onDelete,
}: {
  drawer: DrawerState;
  categories: Category[];
  places: Place[];
  onClose: () => void;
  onDeleteUser: (user: AdminUser, confirmEmail: string) => Promise<void>;
  onFocusUser: (user: AdminUser) => void;
  onUpdate: (
    drawer: DrawerState,
    payload: PlaceUpdatePayload | CategoryUpdatePayload | ScheduleUpdatePayload,
  ) => Promise<void>;
  onDelete: (drawer: DrawerState) => Promise<void>;
}) {
  const [tab, setTab] = useState<"details" | "edit" | "raw">("details");
  const editable =
    drawer.kind === "place" ||
    drawer.kind === "category" ||
    drawer.kind === "schedule";

  useEffect(() => {
    setTab("details");
  }, [drawer]);

  return (
    <aside className="drawer">
      <div className="drawer-head">
        <div>
          <h2>{drawerTitle(drawer)}</h2>
          <p>{drawerSubtitle(drawer)}</p>
        </div>
        <button className="icon-button" onClick={onClose} type="button">
          <X size={18} />
        </button>
      </div>

      <div className="drawer-tabs">
        <button
          className={tab === "details" ? "active" : ""}
          onClick={() => setTab("details")}
          type="button"
        >
          Chi tiết
        </button>
        {editable && (
          <button
            className={tab === "edit" ? "active" : ""}
            onClick={() => setTab("edit")}
            type="button"
          >
            Chỉnh sửa
          </button>
        )}
        <button
          className={tab === "raw" ? "active" : ""}
          onClick={() => setTab("raw")}
          type="button"
        >
          Raw
        </button>
      </div>

      <div className="drawer-body">
        {tab === "details" && (
          <DetailsView
            drawer={drawer}
            onDeleteUser={onDeleteUser}
            onFocusUser={onFocusUser}
          />
        )}
        {tab === "raw" && <pre>{JSON.stringify(drawer.item, null, 2)}</pre>}
        {tab === "edit" && drawer.kind === "place" && (
          <PlaceEditor
            key={drawer.item.id}
            categories={categories}
            place={drawer.item}
            onDelete={() => onDelete(drawer)}
            onSave={(payload) => onUpdate(drawer, payload)}
          />
        )}
        {tab === "edit" && drawer.kind === "category" && (
          <CategoryEditor
            key={drawer.item.id}
            category={drawer.item}
            onDelete={() => onDelete(drawer)}
            onSave={(payload) => onUpdate(drawer, payload)}
          />
        )}
        {tab === "edit" && drawer.kind === "schedule" && (
          <ScheduleEditor
            key={drawer.item.id}
            places={places}
            schedule={drawer.item}
            onDelete={() => onDelete(drawer)}
            onSave={(payload) => onUpdate(drawer, payload)}
          />
        )}
      </div>
    </aside>
  );
}

function DetailsView({
  drawer,
  onDeleteUser,
  onFocusUser,
}: {
  drawer: DrawerState;
  onDeleteUser: (user: AdminUser, confirmEmail: string) => Promise<void>;
  onFocusUser: (user: AdminUser) => void;
}) {
  switch (drawer.kind) {
    case "place":
      return <PlaceDetails place={drawer.item} />;
    case "category":
      return <CategoryDetails category={drawer.item} />;
    case "schedule":
      return <ScheduleDetails schedule={drawer.item} />;
    case "user":
      return (
        <UserDetails
          drawer={drawer}
          onDeleteUser={onDeleteUser}
          onFocusUser={onFocusUser}
        />
      );
    case "activity":
      return (
        <div className="detail-grid">
          <Field label="Loại" value={drawer.item.type} />
          <Field label="Hành động" value={valueOrDash(drawer.item.action)} />
          <Field
            label="Mức"
            value={
              <StatusPill
                tone={toneForSeverity(drawer.item.severity)}
                label={drawer.item.severity}
              />
            }
          />
          <Field label="Thiết bị" value={short(drawer.item.deviceId)} />
          <Field label="Request ID" value={short(drawer.item.requestId)} />
          <Field label="Thời gian" value={formatTime(drawer.item.createdAt)} />
          <Field label="Message" value={valueOrDash(drawer.item.message)} />
        </div>
      );
    case "error":
      return (
        <div className="detail-grid">
          <Field
            label="Endpoint"
            value={`${drawer.item.method} ${drawer.item.path}`}
          />
          <Field
            label="Status"
            value={
              <StatusPill tone="danger" label={`${drawer.item.statusCode}`} />
            }
          />
          <Field label="Name" value={drawer.item.name} />
          <Field label="Message" value={drawer.item.message} />
          <Field label="Thiết bị" value={short(drawer.item.deviceId)} />
          <Field label="Request ID" value={short(drawer.item.requestId)} />
          <Field label="Thời gian" value={formatTime(drawer.item.createdAt)} />
        </div>
      );
    case "request":
      return (
        <div className="detail-grid">
          <Field
            label="Endpoint"
            value={`${drawer.item.method} ${drawer.item.path}`}
          />
          <Field
            label="Response"
            value={
              <StatusPill
                tone={toneForResponse(drawer.item.responseStatus)}
                label={`${drawer.item.statusCode}`}
              />
            }
          />
          <Field label="Duration" value={`${drawer.item.durationMs} ms`} />
          <Field label="Thiết bị" value={short(drawer.item.deviceId)} />
          <Field label="IP" value={valueOrDash(drawer.item.ipAddress)} />
          <Field
            label="User agent"
            value={valueOrDash(drawer.item.userAgent)}
          />
          <Field label="Thời gian" value={formatTime(drawer.item.createdAt)} />
        </div>
      );
    case "upload":
      return (
        <div className="detail-grid">
          <Field label="File" value={valueOrDash(drawer.item.originalName)} />
          <Field label="Storage" value={drawer.item.storage} />
          <Field
            label="Status"
            value={
              <StatusPill
                tone={toneForUpload(drawer.item.status)}
                label={drawer.item.status}
              />
            }
          />
          <Field
            label="Dung lượng"
            value={
              drawer.item.sizeBytes
                ? `${Math.round(drawer.item.sizeBytes / 1024)} KB`
                : "-"
            }
          />
          <Field label="URL" value={<ExternalUrl url={drawer.item.url} />} />
          <Field label="Lỗi" value={valueOrDash(drawer.item.errorMessage)} />
          <Field label="Thời gian" value={formatTime(drawer.item.createdAt)} />
        </div>
      );
  }
}

function PlaceDetails({ place }: { place: Place }) {
  return (
    <div className="detail-stack">
      <PlacePreviewImage name={place.name} url={place.imageUrl} />
      <div className="detail-grid">
        <Field label="User" value={userLabel(place.user)} />
        <Field label="Tên" value={place.name} />
        <Field label="Danh mục" value={place.category?.name ?? "-"} />
        <Field label="Rating" value={<Rating value={place.rating} />} />
        <Field label="Địa chỉ" value={place.address} />
        <Field label="Giờ mở cửa" value={valueOrDash(place.openingHours)} />
        <Field label="Số điện thoại" value={valueOrDash(place.phone)} />
        <Field label="Khoảng giá" value={valueOrDash(place.priceRange)} />
        <Field label="Website" value={<ExternalUrl url={place.website} />} />
        <Field
          label="Google Maps"
          value={<ExternalUrl url={place.mapsUrl} />}
        />
        <Field
          label="Tọa độ"
          value={
            place.latitude != null && place.longitude != null
              ? `${place.latitude}, ${place.longitude}`
              : "-"
          }
        />
        <Field label="Lịch trình" value={place.schedules?.length ?? 0} />
        <Field label="Ngày tạo" value={formatTime(place.createdAt)} />
      </div>
    </div>
  );
}

function UserDetails({
  drawer,
  onDeleteUser,
  onFocusUser,
}: {
  drawer: Extract<DrawerState, { kind: "user" }>;
  onDeleteUser: (user: AdminUser, confirmEmail: string) => Promise<void>;
  onFocusUser: (user: AdminUser) => void;
}) {
  const { item: user, detail } = drawer;
  const [confirmEmail, setConfirmEmail] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function deleteUser() {
    setDeleting(true);
    setError(null);
    try {
      await onDeleteUser(user, confirmEmail);
    } catch (deleteError) {
      setError(
        deleteError instanceof Error
          ? deleteError.message
          : "Không xóa được user",
      );
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="detail-stack">
      <div className="detail-grid">
        <Field label="Email" value={user.email} />
        <Field label="Tên" value={user.name} />
        <Field
          label="Xác thực email"
          value={user.emailVerifiedAt ? formatTime(user.emailVerifiedAt) : "-"}
        />
        <Field
          label="Đăng nhập gần nhất"
          value={user.lastLoginAt ? formatTime(user.lastLoginAt) : "-"}
        />
        <Field
          label="Provider"
          value={
            user.accounts
              .map((account) =>
                account.provider === "PASSWORD" ? "Mật khẩu" : "Google",
              )
              .join(", ") || "-"
          }
        />
        <Field label="Danh mục" value={user._count.categories} />
        <Field label="Địa điểm" value={user._count.places} />
        <Field label="Lịch trình" value={user._count.schedules} />
        <Field label="Ngày tạo" value={formatTime(user.createdAt)} />
      </div>

      <button
        className="primary-button"
        onClick={() => onFocusUser(user)}
        type="button"
      >
        Xem dữ liệu user này
      </button>

      {!detail ? (
        <div className="empty-state">Đang tải dữ liệu user...</div>
      ) : (
        <div className="user-summary">
          <MiniList
            title="Địa điểm gần nhất"
            empty="User chưa có địa điểm."
            items={detail.places.map((place) => ({
              id: place.id,
              title: place.name,
              meta: place.address,
            }))}
          />
          <MiniList
            title="Danh mục"
            empty="User chưa có danh mục."
            items={detail.categories.map((category) => ({
              id: category.id,
              title: category.name,
              meta: `${category._count?.places ?? 0} địa điểm`,
            }))}
          />
          <MiniList
            title="Lịch trình gần nhất"
            empty="User chưa có lịch trình."
            items={detail.schedules.map((schedule) => ({
              id: schedule.id,
              title: schedule.place?.name ?? schedule.placeId,
              meta: `${formatDate(schedule.date)} · ${schedule.time} · ${schedule.status}`,
            }))}
          />
          <MiniList
            title="Lỗi API gần nhất"
            empty="Không có lỗi API."
            items={detail.errors.map((apiError) => ({
              id: apiError.id,
              title: `${apiError.statusCode} ${apiError.path}`,
              meta: apiError.message,
            }))}
          />
        </div>
      )}

      <div className="danger-zone">
        <strong>Xóa user</strong>
        <span>
          Thao tác này xóa tài khoản và toàn bộ dữ liệu liên quan. Nhập lại
          email để xác nhận.
        </span>
        <input
          value={confirmEmail}
          onChange={(event) => setConfirmEmail(event.target.value)}
          placeholder={user.email}
        />
        {error && <div className="form-error">{error}</div>}
        <button
          className="danger-button"
          disabled={
            deleting || confirmEmail.trim().toLowerCase() !== user.email
          }
          onClick={() => void deleteUser()}
          type="button"
        >
          {deleting ? "Đang xóa" : "Xóa user"}
        </button>
      </div>
    </div>
  );
}

function MiniList({
  title,
  empty,
  items,
}: {
  title: string;
  empty: string;
  items: Array<{ id: string; title: string; meta: string }>;
}) {
  return (
    <div className="mini-list">
      <strong>{title}</strong>
      {items.length === 0 ? (
        <span>{empty}</span>
      ) : (
        items.map((item) => (
          <div key={item.id} className="mini-list-row">
            <b>{item.title}</b>
            <span>{item.meta}</span>
          </div>
        ))
      )}
    </div>
  );
}

function PlacePreviewImage({
  name,
  url,
}: {
  name: string;
  url?: string | null;
}) {
  const [failed, setFailed] = useState(false);
  const hasImage = Boolean(url && !failed);

  useEffect(() => {
    setFailed(false);
  }, [url]);

  return (
    <div className="place-preview">
      {hasImage ? (
        <img
          alt={name}
          referrerPolicy="no-referrer"
          src={url ?? undefined}
          onError={() => setFailed(true)}
        />
      ) : (
        <div className="place-preview-fallback">
          <strong>{name}</strong>
          <span>Chưa tải được ảnh</span>
        </div>
      )}
    </div>
  );
}

function CategoryDetails({ category }: { category: Category }) {
  return (
    <div className="detail-grid">
      <Field label="Icon" value={category.icon} />
      <Field label="User" value={userLabel(category.user)} />
      <Field label="Tên" value={category.name} />
      <Field label="Số địa điểm" value={category._count?.places ?? 0} />
      <Field label="Ngày tạo" value={formatTime(category.createdAt)} />
    </div>
  );
}

function ScheduleDetails({ schedule }: { schedule: Schedule }) {
  return (
    <div className="detail-grid">
      <Field label="User" value={userLabel(schedule.user)} />
      <Field
        label="Địa điểm"
        value={schedule.place?.name ?? schedule.placeId}
      />
      <Field label="Ngày" value={formatDate(schedule.date)} />
      <Field label="Giờ" value={schedule.time} />
      <Field
        label="Trạng thái"
        value={
          <StatusPill
            tone={toneForSchedule(schedule.status)}
            label={schedule.status}
          />
        }
      />
      <Field label="Nhắc nhở" value={schedule.hasReminder ? "Có" : "Không"} />
      <Field label="Ngày tạo" value={formatTime(schedule.createdAt)} />
    </div>
  );
}

function PlaceEditor({
  place,
  categories,
  onSave,
  onDelete,
}: {
  place: Place;
  categories: Category[];
  onSave: (payload: PlaceUpdatePayload) => Promise<void>;
  onDelete: () => Promise<void>;
}) {
  const [form, setForm] = useState({
    name: place.name,
    categoryId: place.categoryId,
    address: place.address,
    rating: `${place.rating}`,
    priceRange: place.priceRange ?? "",
    openingHours: place.openingHours ?? "",
    phone: place.phone ?? "",
    website: place.website ?? "",
    mapsUrl: place.mapsUrl ?? "",
    imageUrl: place.imageUrl ?? "",
    note: place.note ?? "",
    latitude: place.latitude?.toString() ?? "",
    longitude: place.longitude?.toString() ?? "",
  });
  const [confirmName, setConfirmName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    try {
      await onSave({
        name: form.name.trim(),
        categoryId: form.categoryId,
        address: form.address.trim(),
        rating: Number(form.rating),
        priceRange: nullableText(form.priceRange),
        openingHours: nullableText(form.openingHours),
        phone: nullableText(form.phone),
        website: nullableText(form.website),
        mapsUrl: nullableText(form.mapsUrl),
        imageUrl: nullableText(form.imageUrl),
        note: nullableText(form.note),
        latitude: nullableNumber(form.latitude),
        longitude: nullableNumber(form.longitude),
      });
    } catch (saveError) {
      setError(
        saveError instanceof Error ? saveError.message : "Không thể lưu",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <form className="edit-form" onSubmit={submit}>
      <FormField label="Tên">
        <input
          value={form.name}
          onChange={(event) => setForm({ ...form, name: event.target.value })}
        />
      </FormField>
      <FormField label="Danh mục">
        <select
          value={form.categoryId}
          onChange={(event) =>
            setForm({ ...form, categoryId: event.target.value })
          }
        >
          {categories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.name}
            </option>
          ))}
        </select>
      </FormField>
      <FormField label="Địa chỉ">
        <textarea
          value={form.address}
          onChange={(event) =>
            setForm({ ...form, address: event.target.value })
          }
        />
      </FormField>
      <FormField label="Rating">
        <input
          min="1"
          max="5"
          step="0.1"
          type="number"
          value={form.rating}
          onChange={(event) => setForm({ ...form, rating: event.target.value })}
        />
      </FormField>
      <FormField label="Khoảng giá">
        <input
          value={form.priceRange}
          onChange={(event) =>
            setForm({ ...form, priceRange: event.target.value })
          }
        />
      </FormField>
      <FormField label="Giờ mở cửa">
        <input
          value={form.openingHours}
          onChange={(event) =>
            setForm({ ...form, openingHours: event.target.value })
          }
        />
      </FormField>
      <FormField label="Số điện thoại">
        <input
          value={form.phone}
          onChange={(event) => setForm({ ...form, phone: event.target.value })}
        />
      </FormField>
      <FormField label="Website">
        <input
          value={form.website}
          onChange={(event) =>
            setForm({ ...form, website: event.target.value })
          }
        />
      </FormField>
      <FormField label="Google Maps">
        <input
          value={form.mapsUrl}
          onChange={(event) =>
            setForm({ ...form, mapsUrl: event.target.value })
          }
        />
      </FormField>
      <FormField label="Ảnh">
        <input
          value={form.imageUrl}
          onChange={(event) =>
            setForm({ ...form, imageUrl: event.target.value })
          }
        />
      </FormField>
      <div className="form-row">
        <FormField label="Latitude">
          <input
            value={form.latitude}
            onChange={(event) =>
              setForm({ ...form, latitude: event.target.value })
            }
          />
        </FormField>
        <FormField label="Longitude">
          <input
            value={form.longitude}
            onChange={(event) =>
              setForm({ ...form, longitude: event.target.value })
            }
          />
        </FormField>
      </div>
      <FormField label="Ghi chú">
        <textarea
          value={form.note}
          onChange={(event) => setForm({ ...form, note: event.target.value })}
        />
      </FormField>
      {error && <div className="form-error">{error}</div>}
      <button className="primary-button" disabled={saving} type="submit">
        {saving ? "Đang lưu..." : "Lưu thay đổi"}
      </button>
      <div className="danger-zone">
        <strong>Xóa địa điểm</strong>
        <p>Nhập đúng tên địa điểm để xác nhận xóa.</p>
        <input
          value={confirmName}
          onChange={(event) => setConfirmName(event.target.value)}
          placeholder={place.name}
        />
        <button
          className="danger-button"
          disabled={confirmName !== place.name}
          onClick={() => void onDelete()}
          type="button"
        >
          Xóa địa điểm
        </button>
      </div>
    </form>
  );
}

function CategoryEditor({
  category,
  onSave,
  onDelete,
}: {
  category: Category;
  onSave: (payload: CategoryUpdatePayload) => Promise<void>;
  onDelete: () => Promise<void>;
}) {
  const [name, setName] = useState(category.name);
  const [icon, setIcon] = useState(category.icon);
  const [confirmName, setConfirmName] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      await onSave({ name: name.trim(), icon: icon.trim() });
    } catch (saveError) {
      setError(
        saveError instanceof Error ? saveError.message : "Không thể lưu",
      );
    }
  }

  return (
    <form className="edit-form" onSubmit={submit}>
      <FormField label="Tên danh mục">
        <input value={name} onChange={(event) => setName(event.target.value)} />
      </FormField>
      <FormField label="Icon">
        <input value={icon} onChange={(event) => setIcon(event.target.value)} />
      </FormField>
      {error && <div className="form-error">{error}</div>}
      <button className="primary-button" type="submit">
        Lưu thay đổi
      </button>
      <div className="danger-zone">
        <strong>Xóa danh mục</strong>
        <p>
          Chỉ xóa được danh mục không còn địa điểm. Nhập đúng tên để xác nhận.
        </p>
        <input
          value={confirmName}
          onChange={(event) => setConfirmName(event.target.value)}
          placeholder={category.name}
        />
        <button
          className="danger-button"
          disabled={confirmName !== category.name}
          onClick={() => void onDelete()}
          type="button"
        >
          Xóa danh mục
        </button>
      </div>
    </form>
  );
}

function ScheduleEditor({
  schedule,
  places,
  onSave,
  onDelete,
}: {
  schedule: Schedule;
  places: Place[];
  onSave: (payload: ScheduleUpdatePayload) => Promise<void>;
  onDelete: () => Promise<void>;
}) {
  const [form, setForm] = useState({
    placeId: schedule.placeId,
    date: toDateInput(schedule.date),
    time: schedule.time,
    status: schedule.status,
    hasReminder: schedule.hasReminder,
  });
  const [error, setError] = useState<string | null>(null);
  const selectablePlaces =
    schedule.place && !places.some((place) => place.id === schedule.placeId)
      ? [schedule.place, ...places]
      : places;

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      await onSave(form);
    } catch (saveError) {
      setError(
        saveError instanceof Error ? saveError.message : "Không thể lưu",
      );
    }
  }

  return (
    <form className="edit-form" onSubmit={submit}>
      <FormField label="Địa điểm">
        <select
          value={form.placeId}
          onChange={(event) =>
            setForm({ ...form, placeId: event.target.value })
          }
        >
          {selectablePlaces.map((place) => (
            <option key={place.id} value={place.id}>
              {place.name}
            </option>
          ))}
        </select>
      </FormField>
      <FormField label="Ngày">
        <input
          type="date"
          value={form.date}
          onChange={(event) => setForm({ ...form, date: event.target.value })}
        />
      </FormField>
      <FormField label="Giờ">
        <input
          value={form.time}
          onChange={(event) => setForm({ ...form, time: event.target.value })}
        />
      </FormField>
      <FormField label="Trạng thái">
        <select
          value={form.status}
          onChange={(event) =>
            setForm({
              ...form,
              status: event.target.value as Schedule["status"],
            })
          }
        >
          <option value="UPCOMING">UPCOMING</option>
          <option value="DONE">DONE</option>
          <option value="CANCELLED">CANCELLED</option>
        </select>
      </FormField>
      <label className="toggle-line">
        <input
          checked={form.hasReminder}
          onChange={(event) =>
            setForm({ ...form, hasReminder: event.target.checked })
          }
          type="checkbox"
        />
        Bật nhắc nhở
      </label>
      {error && <div className="form-error">{error}</div>}
      <button className="primary-button" type="submit">
        Lưu thay đổi
      </button>
      <div className="danger-zone">
        <strong>Xóa lịch trình</strong>
        <p>Thao tác này không thể hoàn tác.</p>
        <button
          className="danger-button"
          onClick={() => void onDelete()}
          type="button"
        >
          Xóa lịch trình
        </button>
      </div>
    </form>
  );
}

function ExternalUrl({ url }: { url?: string | null }) {
  if (!url) return <>-</>;
  return (
    <a href={url} rel="noreferrer" target="_blank">
      {short(url, 38)}
    </a>
  );
}

function userLabel(user?: { email: string } | null) {
  return user?.email ?? "-";
}

function drawerTitle(drawer: DrawerState) {
  switch (drawer.kind) {
    case "place":
    case "category":
      return drawer.item.name;
    case "schedule":
      return drawer.item.place?.name ?? drawer.item.id;
    case "user":
      return drawer.item.email;
    case "error":
    case "request":
      return drawer.item.path;
    case "upload":
      return drawer.item.originalName ?? short(drawer.item.url);
    case "activity":
      return `${drawer.item.type}: ${drawer.item.action ?? "-"}`;
  }
}

function drawerSubtitle(drawer: DrawerState) {
  if (drawer.kind === "place") return drawer.item.address;
  if (drawer.kind === "user") return drawer.item.name;
  if (drawer.kind === "category")
    return `${drawer.item._count?.places ?? 0} địa điểm`;
  if (drawer.kind === "schedule")
    return `${formatDate(drawer.item.date)} · ${drawer.item.time}`;
  if (drawer.kind === "activity")
    return drawer.item.deviceId ?? "Không có device id";
  if (drawer.kind === "error") return drawer.item.message;
  if (drawer.kind === "request") return drawer.item.requestId;
  return drawer.item.storage;
}
