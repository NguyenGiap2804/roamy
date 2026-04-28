# Roamy Backend

Node.js, TypeScript, Express, PostgreSQL, and Prisma backend for Roamy.

## Local Setup

```powershell
npm install
copy .env.example .env
npx prisma migrate dev
npx prisma db seed
npm run dev
```

Default local URL:

```text
http://localhost:4000
```

## Environment

```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/roamy?schema=public"
PORT=4000
NODE_ENV=development
CORS_ORIGIN=*
PUBLIC_BASE_URL=http://localhost:4000
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
```

## Scripts

```bash
npm run dev
npm run build
npm run start
npm run deploy:start
npm run seed
```

`deploy:start` runs `prisma migrate deploy` and then starts `dist/server.js`.

## API

- `GET /health`
- `GET /api/v1/categories`
- `POST /api/v1/categories`
- `GET /api/v1/places`
- `GET /api/v1/places/:id`
- `POST /api/v1/places`
- `PATCH /api/v1/places/:id`
- `DELETE /api/v1/places/:id`
- `GET /api/v1/schedules`
- `GET /api/v1/schedules?date=YYYY-MM-DD`
- `POST /api/v1/schedules`
- `PATCH /api/v1/schedules/:id`
- `DELETE /api/v1/schedules/:id`
- `POST /api/v1/upload`

## Image Upload

`POST /api/v1/upload` accepts multipart form-data field:

```text
image
```

If Cloudinary env vars are configured, images are uploaded to Cloudinary. Otherwise images are written to local `uploads/` and served from `/uploads`.

Local fallback is not production-safe on ephemeral deploy platforms.

## Deploy

Included deploy files:

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

Build command:

```bash
npm ci && npm run build
```

Start command:

```bash
npm run deploy:start
```
