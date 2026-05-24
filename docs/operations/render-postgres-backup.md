# Render Postgres Backup Guide

Tài liệu này dùng cho Roamy production trên Render. Không lưu database URL, mật khẩu, token hoặc file backup vào Git.

## Khi cần backup

- Trước khi chạy migration lớn.
- Trước khi dọn log bằng `Admin > Cài đặt > Retention log`.
- Trước khi sửa/xóa dữ liệu hàng loạt trong admin.
- Ít nhất mỗi tuần một lần khi hệ thống có dữ liệu thật.

## Backup bằng Render Dashboard

1. Vào Render Dashboard.
2. Mở Postgres instance của Roamy.
3. Mở mục `Backups`.
4. Tạo manual backup nếu plan hiện tại hỗ trợ.
5. Đợi trạng thái backup hoàn tất trước khi deploy hoặc chạy tác vụ dọn dữ liệu.

## Backup bằng pg_dump từ máy cá nhân

Chỉ dùng `External Database URL` của Render. Không dùng Internal URL từ máy cá nhân vì URL đó chỉ dùng trong mạng riêng Render.

```powershell
pg_dump "postgresql://USER:PASSWORD@HOST:PORT/DB?sslmode=require" `
  --format=custom `
  --file="roamy-$(Get-Date -Format yyyyMMdd-HHmmss).dump"
```

Kiểm tra nhanh file backup:

```powershell
pg_restore --list "roamy-YYYYMMDD-HHMMSS.dump"
```

## Restore vào database test trước

Không restore thẳng vào production nếu chưa thử trên database test.

```powershell
pg_restore `
  --clean `
  --if-exists `
  --no-owner `
  --dbname="postgresql://USER:PASSWORD@HOST:PORT/DB?sslmode=require" `
  "roamy-YYYYMMDD-HHMMSS.dump"
```

## Checklist sau restore

- `/health` trả về database `online`.
- Admin login được.
- Trang `Địa điểm`, `Danh mục`, `Lịch trình` có dữ liệu đúng.
- Chạy `Upload ảnh > Kiểm tra ảnh` để phát hiện ảnh mất link.
- Tạo thử một địa điểm từ mobile app và xác nhận xuất hiện trong admin.

## Retention hiện tại

Các ngưỡng mặc định:

- Request log: 30 ngày.
- Error log: 90 ngày.
- Activity/System event: 90 ngày.
- Image asset log: 180 ngày.

Có thể đổi bằng biến môi trường Render:

- `REQUEST_LOG_RETENTION_DAYS`
- `ERROR_LOG_RETENTION_DAYS`
- `SYSTEM_EVENT_RETENTION_DAYS`
- `IMAGE_ASSET_RETENTION_DAYS`
