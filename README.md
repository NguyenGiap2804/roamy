# Roamy

Roamy is a Flutter + Node.js personal place planner for saving places, viewing place details, uploading images, previewing locations on Google Maps, and scheduling local reminders.

## Current Stack

- Flutter mobile app
- Provider state management
- Node.js + Express backend
- PostgreSQL + Prisma
- Local notifications
- Google Maps Flutter
- Image upload with Cloudinary support and local fallback

## Run Local Database

```powershell
docker start roamy-postgres
```

If the container does not exist:

```powershell
docker run --name roamy-postgres `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=roamy `
  -p 5432:5432 `
  -d postgres:16
```

## Run Backend

```powershell
cd D:\projectbymyself\Roamy\roamy\backend
npm install
npx prisma migrate dev
npx prisma db seed
npm run dev
```

Default local backend URL:

```text
http://localhost:4000
```

## Run Flutter

Android emulator:

```powershell
cd D:\projectbymyself\Roamy\roamy
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

Windows, Chrome, or desktop:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

## Google Maps Setup

Replace `YOUR_GOOGLE_MAPS_API_KEY` in:

- `android/app/src/main/res/values/strings.xml`
- `ios/Runner/Info.plist`

Enable the Maps SDKs in Google Cloud:

- Maps SDK for Android
- Maps SDK for iOS

## Production Upload Setup

For deploy, configure Cloudinary env vars on Railway/Render:

```env
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
PUBLIC_BASE_URL=https://your-backend-url
```

If Cloudinary env vars are missing, backend falls back to local `uploads/`, which is suitable for local development only.

## Backend Deploy

Deployment config files are in `backend/`:

- `Dockerfile`
- `render.yaml`
- `railway.json`

Required production env vars:

```env
DATABASE_URL=postgresql://...
NODE_ENV=production
CORS_ORIGIN=*
PUBLIC_BASE_URL=https://your-backend-url
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
```

Production start command:

```bash
npm run deploy:start
```

This runs Prisma migrations before starting the API.
