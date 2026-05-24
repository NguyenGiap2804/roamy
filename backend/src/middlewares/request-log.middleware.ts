import { randomUUID } from 'crypto';
import { NextFunction, Request, Response } from 'express';

import { observabilityService, sanitizeForLog } from '../modules/observability/observability.service';

export function requestLogMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  req.requestId = req.get('x-request-id') || randomUUID();
  req.deviceId = req.get('x-roamy-device-id') || undefined;
  res.setHeader('x-request-id', req.requestId);

  const startedAt = process.hrtime.bigint();

  res.on('finish', () => {
    if (!req.originalUrl.startsWith('/api/')) {
      return;
    }

    const durationMs = Number((process.hrtime.bigint() - startedAt) / 1000000n);
    void observabilityService.recordApiRequest({
      requestId: req.requestId!,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs,
      userId: req.userId ?? null,
      deviceId: req.deviceId,
      userAgent: req.get('user-agent') ?? null,
      ipAddress: req.ip,
      query: sanitizeForLog(req.query),
    });
  });

  next();
}
