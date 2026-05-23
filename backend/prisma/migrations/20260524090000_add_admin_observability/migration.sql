CREATE TYPE "SystemEventSeverity" AS ENUM ('DEBUG', 'INFO', 'WARN', 'ERROR');

CREATE TYPE "ImageStorageKind" AS ENUM ('CLOUDINARY', 'LOCAL', 'UNCONFIGURED');

CREATE TYPE "ImageAssetStatus" AS ENUM ('SUCCESS', 'FAILED');

CREATE TABLE "SystemEvent" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "action" TEXT,
    "resourceType" TEXT,
    "resourceId" TEXT,
    "screen" TEXT,
    "message" TEXT,
    "severity" "SystemEventSeverity" NOT NULL DEFAULT 'INFO',
    "deviceId" TEXT,
    "requestId" TEXT,
    "metadata" JSONB,
    "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SystemEvent_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ApiRequestLog" (
    "id" TEXT NOT NULL,
    "requestId" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "statusCode" INTEGER NOT NULL,
    "durationMs" INTEGER NOT NULL,
    "deviceId" TEXT,
    "userAgent" TEXT,
    "ipAddress" TEXT,
    "query" JSONB,
    "responseStatus" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ApiRequestLog_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ApiErrorLog" (
    "id" TEXT NOT NULL,
    "requestId" TEXT,
    "method" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "statusCode" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "details" JSONB,
    "deviceId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ApiErrorLog_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ImageAsset" (
    "id" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "storage" "ImageStorageKind" NOT NULL,
    "status" "ImageAssetStatus" NOT NULL DEFAULT 'SUCCESS',
    "mimeType" TEXT,
    "sizeBytes" INTEGER,
    "originalName" TEXT,
    "deviceId" TEXT,
    "requestId" TEXT,
    "errorMessage" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ImageAsset_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ApiRequestLog_requestId_key" ON "ApiRequestLog"("requestId");
CREATE INDEX "SystemEvent_createdAt_idx" ON "SystemEvent"("createdAt");
CREATE INDEX "SystemEvent_occurredAt_idx" ON "SystemEvent"("occurredAt");
CREATE INDEX "SystemEvent_type_idx" ON "SystemEvent"("type");
CREATE INDEX "SystemEvent_deviceId_idx" ON "SystemEvent"("deviceId");
CREATE INDEX "SystemEvent_resourceType_resourceId_idx" ON "SystemEvent"("resourceType", "resourceId");
CREATE INDEX "ApiRequestLog_createdAt_idx" ON "ApiRequestLog"("createdAt");
CREATE INDEX "ApiRequestLog_method_idx" ON "ApiRequestLog"("method");
CREATE INDEX "ApiRequestLog_statusCode_idx" ON "ApiRequestLog"("statusCode");
CREATE INDEX "ApiRequestLog_deviceId_idx" ON "ApiRequestLog"("deviceId");
CREATE INDEX "ApiErrorLog_createdAt_idx" ON "ApiErrorLog"("createdAt");
CREATE INDEX "ApiErrorLog_statusCode_idx" ON "ApiErrorLog"("statusCode");
CREATE INDEX "ApiErrorLog_path_idx" ON "ApiErrorLog"("path");
CREATE INDEX "ApiErrorLog_deviceId_idx" ON "ApiErrorLog"("deviceId");
CREATE INDEX "ImageAsset_createdAt_idx" ON "ImageAsset"("createdAt");
CREATE INDEX "ImageAsset_storage_idx" ON "ImageAsset"("storage");
CREATE INDEX "ImageAsset_status_idx" ON "ImageAsset"("status");
CREATE INDEX "ImageAsset_deviceId_idx" ON "ImageAsset"("deviceId");
