import { NextFunction, Request, Response } from 'express';

import { observabilityService, sanitizeForLog } from '../observability/observability.service';
import { EventCreateInput } from './event.model';
import { sendResponse } from '../../utils/response';

export class EventController {
  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const body = req.body as EventCreateInput;
      await observabilityService.recordSystemEvent({
        ...body,
        userId: req.userId ?? null,
        deviceId: body.deviceId ?? req.deviceId ?? null,
        requestId: req.requestId ?? null,
        metadata: sanitizeForLog(body.metadata),
        occurredAt: body.occurredAt ? new Date(body.occurredAt) : undefined,
      });

      return sendResponse(res, 202, 'Event accepted', { accepted: true });
    } catch (error) {
      return next(error);
    }
  }
}

export const eventController = new EventController();
