# Roamy Codex Short Commands

When the user sends one of these short commands, treat it as the matching task:

- `/fix notification`: Fix reminder scheduling logic so past reminder times are skipped instead of shown immediately, then verify with Flutter tests/analyze.
- `/fix upload`: Fix backend upload error handling so invalid image input returns a client error and unexpected failures go through the shared error middleware.
- `/fix duplicate category`: Return a clear conflict error when creating a category with an existing name, and surface that message in Flutter.
- `/fix map fallback`: Prevent map screens from opening at `0,0` when a place has no coordinates.
- `/fix backend errors`: Hide stack traces from production API responses while keeping server-side logging.

The current priority is Google Maps extraction and optional place details. Do not add auth/user scope unless the user explicitly asks for it.
