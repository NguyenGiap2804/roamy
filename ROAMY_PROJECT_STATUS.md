# ROAMY – Báo cáo tổng quan dự án

> **Ngày đánh giá:** 2026-05-03
> **Tác giả:** Nguyên Giáp
> **Trạng thái tổng thể:** MVP Phase 1 – Hoàn thành ~70% yêu cầu gốc

---

## 1. TÓM TẮT DỰ ÁN

### 1.1. Mô tả gốc từ khách hàng

> "Mỗi khi tôi đi chơi, tôi cần phải check địa điểm, check nội dung, set up thời gian, nhưng mỗi lần mở đi mở lại ứng dụng Maps để check lại địa điểm tôi muốn... tôi cảm thấy điều đó là quá phiền phức. Tôi cần một app mà ở đó tôi sẽ paste link Google Maps và app tự động lưu và chuyển đổi thành thông tin hiển thị."

### 1.2. Yêu cầu cốt lõi (Core Requirements)

| # | Yêu cầu                                  | Trạng thái |
|---|-------------------------------------------|------------|
| 1 | Paste link Google Maps → tự động trích xuất thông tin | ✅ Hoàn thành |
| 2 | Hiển thị card: tên, địa điểm, giá, giờ mở cửa       | ✅ Hoàn thành |
| 3 | Bấm vào card → xem chi tiết đầy đủ                   | ✅ Hoàn thành |
| 4 | Nút mở Google Maps để di chuyển                       | ✅ Hoàn thành |
| 5 | Icon thông báo → đặt nhắc nhở theo giờ               | ✅ Hoàn thành |
| 6 | Nhắc nhở trước giờ hẹn (ví dụ: trước 30 phút)        | ✅ Hoàn thành |
| 7 | Lịch trình (Calendar) để set lịch hẹn                | ✅ Hoàn thành |
| 8 | Ngày đã qua không được set lịch                       | ✅ Hoàn thành |
| 9 | Danh mục (đi ăn, đi chơi, đi xem phim...)            | ✅ Hoàn thành |
| 10| Tự đánh giá và tự đặt rating cho địa điểm            | ✅ Hoàn thành |

**Kết luận:** Toàn bộ 10/10 yêu cầu cốt lõi ban đầu đã được triển khai.

---

## 2. KIẾN TRÚC HỆ THỐNG HIỆN TẠI

### 2.1. Frontend (Flutter)

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # MultiProvider + MaterialApp setup
├── core/
│   ├── constants/               # AppColors, AppSpacing, AppTextStyles
│   ├── network/                 # ApiClient (HTTP wrapper)
│   ├── theme/                   # Light/Dark theme
│   └── utils/                   # Coordinates, SnackBarHelper
├── data/                        # (reserved, currently empty)
├── models/
│   ├── place.dart               # Place model (14 fields)
│   ├── category.dart            # Category model
│   └── schedule.dart            # Schedule model (UPCOMING/DONE/CANCELLED)
├── providers/
│   ├── place_provider.dart      # CRUD + search + filter
│   ├── category_provider.dart   # CRUD categories
│   ├── schedule_provider.dart   # CRUD + notification sync + optimistic updates
│   └── theme_provider.dart      # Dark/Light toggle
├── services/
│   ├── place_service.dart               # REST API calls cho Place
│   ├── category_service.dart            # REST API calls cho Category
│   ├── schedule_service.dart            # REST API calls cho Schedule
│   ├── notification_service.dart        # Local notification (flutter_local_notifications)
│   ├── google_maps_extraction_service.dart  # Web scraping Google Maps link (~1050 lines)
│   └── place_share_service.dart         # Share card as image (share_plus)
├── screens/
│   ├── splash_screen.dart               # Splash + notification init
│   ├── main_navigation_screen.dart      # Bottom nav: Home, Calendar, Categories, Me
│   ├── home/home_screen.dart            # Home with search + category filter + place list
│   ├── add_place/add_place_screen.dart  # Form thêm/sửa place (~42KB, rất phức tạp)
│   ├── place_detail/place_detail_screen.dart  # Chi tiết place + schedule planner
│   ├── calendar/calendar_screen.dart    # Calendar với week/day view + schedule management
│   ├── categories/categories_screen.dart # Grid danh mục + CRUD
│   ├── visit_history/visit_history_screen.dart # Lịch sử đã đi
│   └── map_screen.dart                  # Google Maps full-screen preview
└── widgets/
    ├── place_card.dart           # Card widget (~11KB, nhiều tính năng)
    ├── category_filter_chip.dart # Horizontal filter chips
    ├── map_preview.dart          # Map preview thumbnail
    ├── rating_stars.dart         # Star rating display
    ├── empty_state.dart          # Empty state placeholder
    ├── section_title.dart        # Section title with icon
    └── primary_button.dart       # Reusable button
```

### 2.2. Backend (Node.js + Express + Prisma + PostgreSQL)

```
backend/
├── src/
│   ├── app.ts                   # Express app setup
│   ├── server.ts                # Server entry point
│   ├── config/                  # Environment config
│   ├── middlewares/             # Error handling, CORS
│   ├── utils/                   # Response helpers
│   └── modules/
│       ├── place/               # CRUD Place (5 files: controller, model, repository, routes, service)
│       ├── category/            # CRUD Category (5 files)
│       ├── schedule/            # CRUD Schedule (5 files)
│       └── upload/              # Image upload
├── prisma/
│   ├── schema.prisma            # Database schema (Category, Place, Schedule)
│   ├── seed.ts                  # Seed data
│   └── migrations/              # Prisma migrations
└── Dockerfile                   # Deployment config
```

### 2.3. Database Schema

```
Category  ──┐
             │ 1:N
Place    ────┘
  │
  │ 1:N
Schedule ────┘

Place fields: id, name, categoryId, address, priceRange, openingHours,
              phone, mapsUrl, note, imageUrl, rating, hasReminder,
              latitude, longitude, createdAt

Schedule fields: id, placeId, date, time, status (UPCOMING/DONE/CANCELLED),
                 hasReminder, createdAt
```

### 2.4. Deployment

- **Backend:** Railway (Dockerfile + PostgreSQL)
- **Frontend:** Flutter Android APK (debug + release builds)

---

## 3. TÍNH NĂNG ĐÃ HOÀN THÀNH (CHI TIẾT)

### 3.1. ✅ Google Maps Link Extraction (Cốt lõi #1)

**File:** `lib/services/google_maps_extraction_service.dart` (~1050 dòng code)

Đây là tính năng phức tạp nhất của hệ thống. Khi user paste link Google Maps:
- **Tự động resolve redirect** (goo.gl → maps.google.com)
- **Trích xuất từ URL path** (@lat,lng, /place/name)
- **Trích xuất từ HTML response** (structured data, meta tags)
- **Trích xuất từ Preview API** (Google Maps preview endpoint)
- **Dữ liệu trích xuất:** Tên, địa chỉ, giá, giờ mở cửa, số điện thoại, rating, tọa độ GPS
- **Hệ thống đánh giá độ tin cậy:** Mỗi kết quả có score (0-1) và confidence level (low/medium/high)
- **Xử lý edge case:** Links bị redirect, consent pages, missing data

**Trạng thái:** Production-ready, đã test với nhiều loại link Google Maps Việt Nam.

### 3.2. ✅ Place Management (CRUD)

- **Thêm địa điểm:** Form phức tạp với auto-fill từ Google Maps link
- **Sửa địa điểm:** Pre-populate form từ dữ liệu cũ
- **Xóa địa điểm:** Confirmation dialog + cascade delete schedules
- **Xem chi tiết:** Full-screen detail với image header, info cards, map preview
- **Upload ảnh:** Chụp từ camera hoặc chọn từ thư viện
- **Share card:** Chia sẻ địa điểm dưới dạng hình ảnh

### 3.3. ✅ Notification System

**File:** `lib/services/notification_service.dart`

- **Exact alarm scheduling** (Android 12+ USE_EXACT_ALARM)
- **Nhắc nhở trước 30 phút** + tại thời điểm bắt đầu
- **Skip past notifications** (không hiện thông báo cho thời gian đã qua)
- **Auto-resync** khi mở app (đồng bộ lại tất cả upcoming schedules)
- **Timezone support** (Asia/Ho_Chi_Minh default)

### 3.4. ✅ Calendar & Schedule System

**File:** `lib/screens/calendar/calendar_screen.dart` (~1183 dòng)

- **Week-by-week navigation** trong tháng
- **Date selection** với filter ngày quá hạn
- **Schedule status management:** UPCOMING → DONE / CANCELLED
- **Quick edit:** Chỉnh giờ + toggle reminder từ bottom sheet
- **Status filter chips:** All / Upcoming / Done / Cancelled
- **Open Maps** trực tiếp từ schedule card

### 3.5. ✅ Category System

- **Backend seeded** với 6 danh mục mặc định
- **CRUD danh mục** từ frontend
- **Filter theo danh mục** trên Home Screen (horizontal chips)
- **Category icon mapping** (local_cafe, restaurant, movie, etc.)
- **Place count** hiển thị số địa điểm mỗi danh mục

### 3.6. ✅ UI/UX

- **Design system:** AppColors, AppSpacing, AppTextStyles
- **Light + Dark theme** với toggle button
- **Vietnamese localization** (80% UI text)
- **Optimistic updates** (UI cập nhật ngay, sync backend sau)
- **Error handling:** Empty state, error state, loading state
- **Pull-to-refresh** trên Home và Calendar
- **Search bar** trên Home Screen

### 3.7. ✅ Visit History

**File:** `lib/screens/visit_history/visit_history_screen.dart`

- Hiển thị các địa điểm đã đánh dấu "Đã đi xong" (DONE)
- Statistics: Completed count, Categories explored, Latest visit
- Action buttons: View details, Open Maps, Visit again

### 3.8. ✅ Testing

12 test files covering:
- Google Maps extraction service
- Place provider
- Schedule provider
- Calendar screen
- Place detail screen
- Visit history screen
- Notification scheduling
- Coordinates utilities
- API client
- Place share service

---

## 4. TÍNH NĂNG CHƯA TRIỂN KHAI

### 4.1. 🔲 EXPLORE SYSTEM (Priority #1)

**Mục tiêu:** Biến Home Screen từ "Storage list" → "Discovery platform"

**Hiện tại:** Home Screen chỉ hiển thị danh sách địa điểm đã lưu với filter + search.

**Cần làm:**

#### A. Chuyển đổi Home Screen
```
Hiện tại:
┌──────────────────────────┐
│ Greeting                 │
│ Search Bar               │
│ Category Filter Chips    │
│ [Địa điểm đã lưu]       │  ← Chỉ hiển thị places user đã lưu
│ Place Card 1             │
│ Place Card 2             │
│ ...                      │
└──────────────────────────┘

Mục tiêu:
┌──────────────────────────┐
│ Greeting / Weather       │  ← MỚI: Weather card
│ Category Filter Chips    │
│ [Nearby Places]          │  ← MỚI: Section gợi ý gần đây
│ [Popular Places]         │  ← MỚI: Section phổ biến nhất
│ [Recommended]            │  ← MỚI: Section gợi ý cá nhân
└──────────────────────────┘
```

#### B. Backend API mới cần tạo
```
GET /api/v1/places?sort=rating&limit=5          # Popular places
GET /api/v1/places?sort=distance&lat=X&lng=Y    # Nearby places (optional)
GET /api/v1/places?category=cafe&sort=rating     # Category + sort combo
```

#### C. Frontend thay đổi
- Di chuyển "Địa điểm đã lưu" từ Home sang tab "Tôi" (Profile)
- Tạo các section mới: Nearby, Popular, Recommended
- Thêm horizontal scroll list cho từng section
- Cache data trong bộ nhớ, filter cục bộ khi chuyển category

#### D. Ước tính công việc
- **Backend:** 1-2 endpoints mới (sort + filter params)
- **Frontend:** Redesign home_screen.dart, tạo các widget section mới
- **Độ khó:** ⭐⭐⭐ Trung bình
- **Thời gian ước tính:** 2-3 ngày

---

### 4.2. 🔲 SMART TRIP (Priority #2)

**Mục tiêu:** Tự động tạo lịch trình trong ngày dựa trên danh mục đã chọn.

**Hiện tại:** User phải tự tay lên lịch cho từng địa điểm riêng lẻ.

**Cần làm:**

#### A. Backend API
```
POST /api/v1/smart-trip
Input: { categories: ["cafe", "movie", "food"], date: "2026-05-20" }
Output: { plan: [...], explanation: [...] }
```

#### B. Business Logic (Rule-based, KHÔNG dùng AI)
```
1. Filter places theo categories đã chọn
2. Ưu tiên: rating cao + valid opening hours
3. Gán duration mặc định nếu thiếu:
   - Cafe: 90 phút
   - Movie: 120 phút
   - Food: 90 phút
   - Other: 60 phút
4. Sắp xếp theo thứ tự logic:
   - Cafe → Activity → Movie → Food
5. Generate timeline:
   - Start: 13:00 (default)
   - Buffer: 30 phút giữa các hoạt động
6. Validate opening hours + no overlap
```

#### C. Frontend Screen mới
```
Smart Trip Screen:
┌──────────────────────────┐
│ [Multi-select categories]│
│ [Date picker]            │
│ [Button: Generate Plan]  │
│                          │
│ Timeline:                │
│ 13:00-14:30 → Cafe       │
│ 15:00-17:00 → Movie      │
│ 18:00-19:30 → Food       │
│                          │
│ Explanation:             │
│ "Cafe đầu tiên vì..."   │
└──────────────────────────┘
```

#### D. Database changes
- Thêm field `estimatedDuration` vào Place model (optional)

#### E. Ước tính công việc
- **Backend:** 1 endpoint + scheduling algorithm (~200-300 lines)
- **Frontend:** 1 screen mới + integration vào navigation
- **Độ khó:** ⭐⭐⭐⭐ Khó (business logic phức tạp)
- **Thời gian ước tính:** 3-5 ngày

---

### 4.3. 🔲 WEATHER INTEGRATION (Priority #3)

**Mục tiêu:** Hiển thị thời tiết + gợi ý loại hình phù hợp trên Home Screen.

**Hiện tại:** Không có thông tin thời tiết.

**Cần làm:**

#### A. API Integration
- Dùng OpenWeatherMap API (free tier)
- Fetch 1 lần khi mở app, cache 15-30 phút

#### B. Weather Card UI
```
┌──────────────────────────┐
│ 📍 Hà Nội               │
│ 🌤 30°C                  │
│ "Trời đẹp, rất thích     │
│  hợp đi cafe ☕"          │
└──────────────────────────┘
```

#### C. Suggestion Logic (Rule-based)
```
Sunny → "Thời tiết đẹp, nên đi cafe hoặc dạo phố"
Rain  → "Trời mưa, nên chọn đi xem phim hoặc ở trong nhà"
Hot   → "Trời nóng, nên chọn nơi có điều hòa"
```

#### D. Integration với Smart Trip (tùy chọn)
- Rain → ưu tiên indoor places
- Sunny → ưu tiên outdoor places

#### E. Cần tạo
```
lib/services/weather_service.dart     # API call + cache
lib/models/weather.dart               # Weather model
lib/widgets/weather_card.dart         # Weather card widget
```

#### F. Ước tính công việc
- **Backend:** Không cần (gọi trực tiếp từ Flutter)
- **Frontend:** 3 files mới + integrate vào Home Screen
- **Độ khó:** ⭐⭐ Dễ
- **Thời gian ước tính:** 1-2 ngày
- **Yêu cầu:** API key OpenWeatherMap (free)

---

### 4.4. 🔲 AI PLACE RECOMMENDATION (Priority #4 – Optional)

**Mục tiêu:** Gợi ý địa điểm cá nhân hóa dựa trên hành vi user.

**Hiện tại:** Không có hệ thống gợi ý.

**Cần làm:**

#### A. Version 1: Rule-based (Không AI)
```
1. Đếm tần suất categories user lưu/đánh giá cao
   Cafe: 5, Movie: 2, Food: 1 → Priority: Cafe > Movie > Food
2. Filter places theo top categories
3. Score mỗi place:
   score = (rating * 2) + (category_match_weight) + (recent_activity_bonus)
4. Sort giảm dần, trả về top 3-5 places
```

#### B. Version 2: AI Enhancement (Tùy chọn)
- Dùng Gemini/OpenAI API để generate mô tả ngắn cho mỗi gợi ý
- Input: place name, category, rating, user context
- Output: "Quán cafe phù hợp cho buổi chiều thư giãn..."

#### C. Backend API
```
GET /api/v1/recommendations
Response: { recommendations: [{ placeId, name, category, rating, reason, aiDescription }] }
```

#### D. Frontend
- Section "🔥 Gợi ý cho bạn" trên Home Screen
- Horizontal scroll list
- Fallback text nếu không có AI

#### E. Ước tính công việc
- **Rule-based version:** 2-3 ngày
- **AI version:** 4-5 ngày thêm (cần API key + prompt engineering)
- **Độ khó:** ⭐⭐⭐⭐⭐ Rất khó (nếu có AI)

---

## 5. TECHNICAL DEBT (Nợ kỹ thuật)

| # | Vấn đề | Mức độ | Ghi chú |
|---|--------|--------|---------|
| 1 | `add_place_screen.dart` quá lớn (42KB) | ⚠️ Medium | Nên refactor thành nhiều widget nhỏ |
| 2 | `calendar_screen.dart` quá lớn (38KB) | ⚠️ Medium | Tách logic ra khỏi UI |
| 3 | `place_detail_screen.dart` (33KB) | ⚠️ Medium | Tương tự |
| 4 | Hardcode user name "Nguyên Giáp" | 🔵 Low | Chưa có auth system |
| 5 | `share_plus` deprecated API warnings | 🔵 Low | Chờ plugin update |
| 6 | KGP warnings từ third-party plugins | 🔵 Low | Upstream issue, không thể fix |
| 7 | Thiếu localization framework (intl) | 🔵 Low | Hiện đang hardcode tiếng Việt |
| 8 | Chưa có user authentication | 🟡 Medium | Chưa cần cho MVP |
| 9 | Chưa có offline mode / local database | 🟡 Medium | Cần internet để hoạt động |

---

## 6. LỘ TRÌNH PHÁT TRIỂN (ROADMAP)

### Phase 2: Explore & Discovery (Tuần 1-2)

```
Week 1:
- [ ] Redesign Home Screen → Discovery layout
- [ ] Tạo sections: Popular, Nearby (optional)
- [ ] Di chuyển "Saved Places" sang tab "Tôi"
- [ ] Weather Card integration (OpenWeatherMap)

Week 2:
- [ ] Smart Trip MVP (rule-based scheduling)
- [ ] Smart Trip UI screen
- [ ] Integration test cho Smart Trip logic
```

### Phase 3: Intelligence & Polish (Tuần 3-4)

```
Week 3:
- [ ] Simple Recommendation engine (rule-based)
- [ ] "Gợi ý cho bạn" section trên Home
- [ ] Refactor large screen files
- [ ] Add proper localization (intl package)

Week 4:
- [ ] AI description generation (optional, Gemini API)
- [ ] Weather-based filtering trong Smart Trip
- [ ] Performance optimization & testing
- [ ] Production build & deployment
```

---

## 7. HƯỚNG DẪN CHO AI ASSISTANT

> Khi AI assistant (Codex, Cursor, Gemini, v.v.) đọc file này, hãy tuân theo các quy tắc sau:

### 7.1. Quy tắc code

- **State management:** Dùng `Provider` + `ChangeNotifier` (đã thiết lập)
- **Architecture:** Service → Provider → Screen (3-layer)
- **Styling:** Dùng `AppColors`, `AppSpacing`, `AppTextStyles` (KHÔNG dùng hardcode values)
- **Theme:** Luôn hỗ trợ cả Light và Dark mode
- **Language:** UI text bằng tiếng Việt (trừ technical terms)
- **Error handling:** Dùng `SnackBarHelper.showSuccess/showError`

### 7.2. Cấu trúc file

```
Mỗi feature mới cần:
1. Model      → lib/models/
2. Service    → lib/services/     (API calls)
3. Provider   → lib/providers/    (State management)
4. Screen     → lib/screens/      (UI)
5. Widget     → lib/widgets/      (Reusable components)
6. Test       → test/             (Unit + Widget tests)
```

### 7.3. Backend

```
Mỗi module mới cần:
1. model.ts       → Validation schema (Zod)
2. repository.ts  → Prisma database queries
3. service.ts     → Business logic
4. controller.ts  → Request handling
5. routes.ts      → Express routes
```

### 7.4. Ưu tiên hiện tại

```
1. Explore System (redesign Home Screen)
2. Smart Trip
3. Weather Integration
4. AI Recommendation (tùy chọn)
```

**KHÔNG thêm auth/user scope trừ khi được yêu cầu rõ ràng.**

---

## 8. THỐNG KÊ

| Metric | Giá trị |
|--------|---------|
| Tổng files Dart (lib/) | ~25 files |
| Tổng files TypeScript (backend/) | ~18 files |
| Tổng test files | 12 files |
| Tổng screens | 8 screens |
| Tổng widgets | 7 reusable widgets |
| Tổng providers | 4 providers |
| Tổng services | 6 services (Flutter) + 3 modules (Backend) |
| Database tables | 3 (Category, Place, Schedule) |
| Kích thước Google Maps extraction | ~1050 dòng |
| Dependencies chính | flutter, provider, http, google_maps_flutter, flutter_local_notifications, image_picker, url_launcher, share_plus, path_provider |

---

*File này được tạo để làm tài liệu tham chiếu cho bất kỳ AI assistant nào tiếp tục phát triển dự án Roamy. Chỉ cần đọc file này là có đủ context để bắt đầu làm việc.*
