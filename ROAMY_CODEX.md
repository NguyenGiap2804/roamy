# Roamy Technical Codex

This document serves as the architectural blueprint and implementation guide for the **Roamy** Flutter application. Use this as a reference to understand the current logic and extend the system.

## 1. Architecture Overview
Roamy follows a **Provider-based State Management** pattern combined with a Service-oriented layer.

*   **Models (`lib/models/`)**: Plain Data Classes with `fromJson` and `toMap` methods.
*   **Services (`lib/services/`)**: Pure logic and API interaction layers (e.g., `ApiClient`, `PlaceService`).
*   **Providers (`lib/providers/`)**: `ChangeNotifier` classes that hold app state and interact with services.
*   **Core (`lib/core/`)**: Constants for theme, colors, spacing, and network config.
*   **Widgets (`lib/widgets/`)**: Reusable UI components.
*   **Screens (`lib/screens/`)**: Full-page layouts.

---

## 2. Core Implementation Logic

### A. Google Maps Data Extraction
**Logic**: Extracting metadata from a Google Maps URL without using a paid API.
*   **Service**: `GoogleMapsExtractionService`
*   **How it works**:
    1.  Uses `http` to fetch the URL content.
    2.  Handles redirects (especially `maps.app.goo.gl` to full URLs).
    3.  Uses **Regex patterns** to find:
        *   Place Name: Meta tags or Title.
        *   Rating: Patterns like `(\d\.\d) stars`.
        *   Address: Specific strings between common markers.
        *   Coordinates: Patterns like `@(\d+\.\d+),(\d+\.\d+)`.
*   **Constraint**: Extremely sensitive to Google Maps UI changes. Regex must be updated if scraping fails.

### B. Dynamic Theme Management (Dark Mode)
**Logic**: Global reactivity to theme changes.
*   **Provider**: `ThemeProvider`
*   **Implementation**:
    1.  Maintains a `ThemeMode` state.
    2.  `AppTheme` class defines `ThemeData.light` and `ThemeData.dark`.
    3.  **Crucial**: Widgets should use `Theme.of(context).colorScheme.surface` or `Theme.of(context).dividerColor` instead of hardcoded colors to adapt automatically.
    4.  `AppTextStyles` provides standard typography without hardcoded colors to inherit theme defaults.

### C. Scheduling & Notifications
**Logic**: Precise reminders for future visits.
*   **Service**: `NotificationService` (Wrapper for `flutter_local_notifications`).
*   **Logic**:
    1.  Uses **Time Zones** (`timezone/timezone.dart`) for reliable scheduling.
    2.  Requires `exact_alarm` permissions on Android.
    3.  `ScheduleProvider` manages the CRUD for schedules and triggers `NotificationService.scheduleNotification`.
    4.  Past notifications are automatically skipped or rescheduled on app boot.

### D. API Interaction
*   **Client**: `ApiClient` handles base URLs, headers, and standard error handling.
*   **Endpoints**: Defined in `ApiEndpoints`.
*   **Error Handling**: Centralized in the backend middleware, surfaced in the frontend via `errorMessage` properties in Providers.

---

## 3. UI/UX Standards
*   **Spacing**: Always use `AppSpacing` constants (e.g., `AppSpacing.md`) for padding/margins.
*   **Aesthetics**: Use `LinearGradient` overlays on images for text readability (see `PlaceCard`).
*   **Safe Areas**: Always use `MediaQuery.of(context).padding.bottom` for bottom actions to prevent overlap with system bars.

---

## 4. How to add a new feature
1.  **Model**: Create the data model in `lib/models/`.
2.  **Service**: Add API logic in `lib/services/`.
3.  **Provider**: Create a `ChangeNotifier` and register it in `lib/app.dart`.
4.  **UI**: Build the screen and use `Consumer<NewProvider>` to bind data.

---

## 5. Known Gotchas
*   **Android 12+ Splash**: Managed via `android/app/src/main/res/values-night/styles.xml`.
*   **Scraping Block**: Google may block requests if they detect bot-like behavior. Use proper Headers.
*   **Notification Delay**: Check battery optimization settings on physical devices.
