CREATE TYPE "AuthProvider" AS ENUM ('PASSWORD', 'GOOGLE');

CREATE TYPE "EmailTokenType" AS ENUM ('VERIFY_EMAIL', 'RESET_PASSWORD');

CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "avatarUrl" TEXT,
    "passwordHash" TEXT,
    "emailVerifiedAt" TIMESTAMP(3),
    "lastLoginAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AuthAccount" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "provider" "AuthProvider" NOT NULL,
    "providerAccountId" TEXT NOT NULL,
    "email" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuthAccount_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "replacedByTokenId" TEXT,
    "deviceId" TEXT,
    "userAgent" TEXT,
    "ipAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "EmailToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" "EmailTokenType" NOT NULL,
    "codeHash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmailToken_pkey" PRIMARY KEY ("id")
);

INSERT INTO "User" ("id", "email", "name", "emailVerifiedAt", "createdAt", "updatedAt")
VALUES (
    '00000000-0000-4000-8000-000000000001',
    'legacy@roamy.local',
    'Roamy Legacy Owner',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
)
ON CONFLICT ("id") DO NOTHING;

ALTER TABLE "Category" ADD COLUMN "userId" TEXT;
UPDATE "Category" SET "userId" = '00000000-0000-4000-8000-000000000001' WHERE "userId" IS NULL;
ALTER TABLE "Category" ALTER COLUMN "userId" SET NOT NULL;

ALTER TABLE "Place" ADD COLUMN "userId" TEXT;
UPDATE "Place" SET "userId" = '00000000-0000-4000-8000-000000000001' WHERE "userId" IS NULL;
ALTER TABLE "Place" ALTER COLUMN "userId" SET NOT NULL;

ALTER TABLE "Schedule" ADD COLUMN "userId" TEXT;
UPDATE "Schedule" AS s
SET "userId" = p."userId"
FROM "Place" AS p
WHERE s."placeId" = p."id" AND s."userId" IS NULL;
UPDATE "Schedule" SET "userId" = '00000000-0000-4000-8000-000000000001' WHERE "userId" IS NULL;
ALTER TABLE "Schedule" ALTER COLUMN "userId" SET NOT NULL;

ALTER TABLE "SystemEvent" ADD COLUMN "userId" TEXT;
ALTER TABLE "ApiRequestLog" ADD COLUMN "userId" TEXT;
ALTER TABLE "ApiErrorLog" ADD COLUMN "userId" TEXT;
ALTER TABLE "ImageAsset" ADD COLUMN "userId" TEXT;

DROP INDEX IF EXISTS "Category_name_key";

CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
CREATE INDEX "User_createdAt_idx" ON "User"("createdAt");
CREATE INDEX "User_lastLoginAt_idx" ON "User"("lastLoginAt");
CREATE UNIQUE INDEX "AuthAccount_provider_providerAccountId_key" ON "AuthAccount"("provider", "providerAccountId");
CREATE INDEX "AuthAccount_userId_idx" ON "AuthAccount"("userId");
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");
CREATE INDEX "RefreshToken_expiresAt_idx" ON "RefreshToken"("expiresAt");
CREATE INDEX "RefreshToken_revokedAt_idx" ON "RefreshToken"("revokedAt");
CREATE INDEX "EmailToken_userId_type_createdAt_idx" ON "EmailToken"("userId", "type", "createdAt");
CREATE INDEX "EmailToken_expiresAt_idx" ON "EmailToken"("expiresAt");
CREATE UNIQUE INDEX "Category_userId_name_key" ON "Category"("userId", "name");
CREATE INDEX "Category_userId_idx" ON "Category"("userId");
CREATE INDEX "Place_userId_idx" ON "Place"("userId");
CREATE INDEX "Place_userId_categoryId_idx" ON "Place"("userId", "categoryId");
CREATE INDEX "Place_userId_createdAt_idx" ON "Place"("userId", "createdAt");
CREATE INDEX "Place_userId_rating_idx" ON "Place"("userId", "rating");
CREATE INDEX "Schedule_userId_idx" ON "Schedule"("userId");
CREATE INDEX "Schedule_userId_date_idx" ON "Schedule"("userId", "date");
CREATE INDEX "SystemEvent_userId_idx" ON "SystemEvent"("userId");
CREATE INDEX "ApiRequestLog_userId_idx" ON "ApiRequestLog"("userId");
CREATE INDEX "ApiErrorLog_userId_idx" ON "ApiErrorLog"("userId");
CREATE INDEX "ImageAsset_userId_idx" ON "ImageAsset"("userId");

ALTER TABLE "AuthAccount" ADD CONSTRAINT "AuthAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EmailToken" ADD CONSTRAINT "EmailToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Category" ADD CONSTRAINT "Category_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Place" ADD CONSTRAINT "Place_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Schedule" ADD CONSTRAINT "Schedule_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SystemEvent" ADD CONSTRAINT "SystemEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ApiRequestLog" ADD CONSTRAINT "ApiRequestLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ApiErrorLog" ADD CONSTRAINT "ApiErrorLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ImageAsset" ADD CONSTRAINT "ImageAsset_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
