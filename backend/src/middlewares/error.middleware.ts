import { NextFunction, Request, Response } from 'express';
import { Prisma } from '@prisma/client';

import { AppError } from '../utils/errors';

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
  if (error instanceof AppError) {
    return res.status(error.statusCode).json({
      data: error.details ?? null,
      message: error.message,
      status: error.statusCode,
    });
  }

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    return res.status(400).json({
      data: null,
      message: 'Database request failed',
      status: 400,
    });
  }

  console.error(error);

  return res.status(500).json({
    data: null,
    message: error.message || 'Internal server error',
    errorName: error.name,
    stack: error.stack,
    status: 500,
  });
}
