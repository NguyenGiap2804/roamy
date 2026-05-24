import { NextFunction, Request, Response } from 'express';

import { observabilityService } from '../observability/observability.service';
import { requireUserId } from '../auth/auth.middleware';
import { sendResponse } from '../../utils/response';
import { scheduleService } from './schedule.service';

export class ScheduleController {
  async findAll(req: Request, res: Response, next: NextFunction) {
    try {
      const date = typeof req.query.date === 'string' ? req.query.date : undefined;
      const schedules = await scheduleService.findAll(requireUserId(req), date);
      return sendResponse(res, 200, 'Schedules fetched successfully', schedules);
    } catch (error) {
      return next(error);
    }
  }

  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const schedule = await scheduleService.create(requireUserId(req), req.body);
      void observabilityService.recordSystemEvent({
        type: 'schedule',
        action: 'create',
        resourceType: 'schedule',
        resourceId: schedule.id,
        message: `Created schedule for ${schedule.place.name}`,
        userId: req.userId,
        deviceId: req.deviceId,
        requestId: req.requestId,
        metadata: { date: schedule.date, time: schedule.time },
      });
      return sendResponse(res, 201, 'Schedule created successfully', schedule);
    } catch (error) {
      return next(error);
    }
  }

  async update(req: Request, res: Response, next: NextFunction) {
    try {
      const schedule = await scheduleService.update(req.params.id as string, req.body, requireUserId(req));
      void observabilityService.recordSystemEvent({
        type: 'schedule',
        action: 'update',
        resourceType: 'schedule',
        resourceId: schedule.id,
        message: `Updated schedule for ${schedule.place.name}`,
        userId: req.userId,
        deviceId: req.deviceId,
        requestId: req.requestId,
        metadata: { changedFields: Object.keys(req.body ?? {}) },
      });
      return sendResponse(res, 200, 'Schedule updated successfully', schedule);
    } catch (error) {
      return next(error);
    }
  }

  async delete(req: Request, res: Response, next: NextFunction) {
    try {
      const deleted = await scheduleService.delete(req.params.id as string, requireUserId(req));
      void observabilityService.recordSystemEvent({
        type: 'schedule',
        action: 'delete',
        resourceType: 'schedule',
        resourceId: deleted.id,
        message: `Deleted schedule ${deleted.id}`,
        userId: req.userId,
        deviceId: req.deviceId,
        requestId: req.requestId,
      });
      return sendResponse(res, 200, 'Schedule deleted successfully', deleted);
    } catch (error) {
      return next(error);
    }
  }
}

export const scheduleController = new ScheduleController();
