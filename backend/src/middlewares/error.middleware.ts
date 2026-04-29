import { NextFunction, Request, Response } from "express";
import { Prisma } from "@prisma/client";

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
  _req: Request,
  res: Response,
  _next: NextFunction,
) {
  const isProduction = process.env.NODE_ENV === "production";

  if (error instanceof AppError) {
    return res.status(error.statusCode).json({
      data: error.details ?? null,
      message: error.message,
      status: error.statusCode,
    });
  }

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    console.error(error);

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
