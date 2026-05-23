import { NextFunction, Request, Response } from "express";
import { Prisma } from "@prisma/client";

import {
  observabilityService,
  sanitizeForLog,
} from "../modules/observability/observability.service";
import { AppError } from "../utils/errors";

export function notFoundHandler(req: Request, res: Response) {
  return res.status(404).json({
    data: null,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
    status: 404,
  });
}

export function errorMiddleware(
  error: Error,
  req: Request,
  res: Response,
  _next: NextFunction,
) {
  const isProduction = process.env.NODE_ENV === "production";
  logServerError(req, error);

  if (error instanceof AppError) {
    const isServerError = error.statusCode >= 500;
    return res.status(error.statusCode).json({
      data: isProduction && isServerError
          ? null
          : sanitizeErrorDetails(error.details, isProduction),
      message: isProduction && isServerError
          ? "Internal server error"
          : error.message,
      status: error.statusCode,
    });
  }

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    return res.status(400).json({
      data: null,
      message: "Database request failed",
      status: 400,
    });
  }

  console.error(error);

  const responseBody: {
    data: null;
    message: string;
    status: number;
    errorName?: string;
    stack?: string;
  } = {
    data: null,
    message: isProduction
      ? "Internal server error"
      : error.message || "Internal server error",
    status: 500,
  };

  if (!isProduction) {
    responseBody.errorName = error.name;
    responseBody.stack = error.stack;
  }

  return res.status(500).json(responseBody);
}

function logServerError(req: Request, error: Error) {
  const statusCode =
    error instanceof AppError
      ? error.statusCode
      : error instanceof Prisma.PrismaClientKnownRequestError
      ? 400
      : 500;

  void observabilityService.recordApiError({
    requestId: req.requestId ?? null,
    method: req.method,
    path: req.originalUrl,
    statusCode,
    name: error.name,
    message: error.message,
    details: sanitizeForLog(error instanceof AppError ? error.details : null),
    deviceId: req.deviceId ?? null,
  });

  console.error("[Roamy API Error]", {
    method: req.method,
    url: req.originalUrl,
    statusCode,
    name: error.name,
    message: error.message,
    stack: error.stack,
    details: error instanceof AppError ? error.details : undefined,
  });
}

function sanitizeErrorDetails(details: unknown, isProduction: boolean): unknown {
  if (!isProduction || details == null) {
    return details ?? null;
  }

  if (Array.isArray(details)) {
    return details.map((item) => sanitizeErrorDetails(item, true));
  }

  if (typeof details === "object") {
    const objectDetails = details as Record<string, unknown>;
    const sanitizedEntries = Object.entries(objectDetails)
      .filter(([key]) => !isInternalErrorField(key))
      .map(([key, value]) => [key, sanitizeErrorDetails(value, true)]);
    return Object.fromEntries(sanitizedEntries);
  }

  return details;
}

function isInternalErrorField(key: string) {
  return key === "stack" || key === "stackTrace" || key === "errorName";
}
